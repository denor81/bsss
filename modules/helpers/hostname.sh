# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Validates a short static hostname
# @params:      hostname Hostname to validate (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 valid hostname
#               1 invalid hostname
hostname::name::is_valid() {
    [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}

# @type:        Source
# @description: Requests a validated short hostname from the user
# @stdin:       User input from the controlling terminal
# @stdout:      hostname\0
# @exit_code:   0 hostname received
#               2 cancelled by user
hostname::ui::get_new() {
    local pattern="^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$"

    io::ask_value "$(_ "hostname.ui.prompt")" "" "$pattern" "$(_ "hostname.ui.hint")" "^0$"
}

# @type:        Validator
# @description: Checks whether cloud-init is installed or has a system configuration
# @stdin:       None
# @stdout:      None
# @exit_code:   0 cloud-init detected
#               1 cloud-init not detected
hostname::cloud_init::is_installed() {
    command -v cloud-init >/dev/null 2>&1 || [[ -f "$CLOUD_INIT_CONFIG_FILE" ]]
}

# @type:        Source
# @description: Lists cloud-init configuration files in load order
# @stdin:       None
# @stdout:      path\0 (0..N)
# @exit_code:   0 one or more files found
#               1 no configuration files found
hostname::cloud_init::get_config_files() {
    (
        shopt -s nullglob
        local files=()
        [[ -f "$CLOUD_INIT_CONFIG_FILE" ]] && files+=("$CLOUD_INIT_CONFIG_FILE")
        files+=("${CLOUD_INIT_CONFIGD_DIR}/"*.cfg)
        (( ${#files[@]} > 0 )) && printf '%s\0' "${files[@]}"
    )
}

# @type:        Source
# @description: Reads the last valid preserve_hostname value from cloud-init configuration
# @stdin:       None
# @stdout:      true\0, false\0, or unset\0
# @exit_code:   0 setting resolved
hostname::cloud_init::get_preserve_setting() {
    local file line value setting="unset"

    while IFS= read -r -d '' file; do
        line=$(grep -E '^[[:space:]]*preserve_hostname[[:space:]]*:' "$file" | tail -n1 || true)
        [[ -n "$line" ]] || continue

        value="${line#*:}"
        value="${value%%#*}"
        value="${value//[[:space:]\"\']/}"
        value="${value,,}"
        case "$value" in
            true|false) setting="$value" ;;
        esac
    done < <(hostname::cloud_init::get_config_files || true)

    printf '%s\0' "$setting"
}

# @type:        Validator
# @description: Checks whether cloud-init preserves the locally configured hostname
# @stdin:       None
# @stdout:      None
# @exit_code:   0 hostname is preserved
#               1 hostname may be overwritten
hostname::cloud_init::preserves_hostname() {
    local setting
    setting=$(hostname::cloud_init::get_preserve_setting | tr -d '\0')
    [[ "$setting" == "true" ]]
}

# @type:        Sink
# @description: Creates a BSSS cloud-init override that preserves the hostname
# @stdin:       None
# @stdout:      None
# @exit_code:   0 override created or already effective
#               1 file creation failed
hostname::cloud_init::ensure_preserved() {
    if ! hostname::cloud_init::is_installed; then
        log_info "$(_ "hostname.cloud_init.not_installed")"
        return
    fi

    if hostname::cloud_init::preserves_hostname; then
        log_info "$(_ "hostname.cloud_init.preserved")"
        return
    fi

    mkdir -p "$CLOUD_INIT_CONFIGD_DIR"
    chmod 755 "$CLOUD_INIT_CONFIGD_DIR"

    if cat > "$BSSS_CLOUD_INIT_HOSTNAME_FILE" << EOF
# $BSSS_MARKER_COMMENT
# Preserve the locally configured hostname
preserve_hostname: true
EOF
    then
        chmod 644 "$BSSS_CLOUD_INIT_HOSTNAME_FILE"
        log_info "$(_ "hostname.cloud_init.config_created" "$BSSS_CLOUD_INIT_HOSTNAME_FILE")"
    else
        log_error "$(_ "common.error.create_file" "$BSSS_CLOUD_INIT_HOSTNAME_FILE")"
        return 1
    fi
}

# @type:        Filter
# @description: Replaces the old hostname on the 127.0.1.1 hosts entry while preserving aliases
# @params:      old_hostname Current short hostname (string) without a terminator
#               new_hostname New short hostname (string) without a terminator
# @stdin:       hosts file content (text\n)
# @stdout:      updated hosts file content (text\n)
# @exit_code:   0 content transformed
#               $? gawk failure
hostname::hosts::replace() {
    local old_hostname="$1"
    local new_hostname="$2"

    gawk -v old="$old_hostname" -v new="$new_hostname" '
        BEGIN {
            OFS = "\t"
            first_host_line = 0
            mapped = 0
        }
        {
            if ($1 == "127.0.1.1") {
                if (first_host_line == 0) {
                    first_host_line = NR
                }
                for (i = 2; i <= NF; i++) {
                    if ($i == old) {
                        $i = new
                        mapped = 1
                    } else if (index($i, old ".") == 1) {
                        $i = new substr($i, length(old) + 1)
                        mapped = 1
                    } else if ($i == new || index($i, new ".") == 1) {
                        mapped = 1
                    }
                }
            }
            lines[NR] = $0
        }
        END {
            if (!mapped) {
                if (first_host_line > 0) {
                    lines[first_host_line] = lines[first_host_line] OFS new
                } else {
                    lines[++NR] = "127.0.1.1" OFS new
                }
            }
            for (i = 1; i <= NR; i++) {
                print lines[i]
            }
        }
    '
}

# @type:        Validator
# @description: Checks whether the 127.0.1.1 hosts entry contains the hostname
# @params:      hostname Short hostname to find (string) without a terminator
# @stdin:       hosts file content (text\n)
# @stdout:      None
# @exit_code:   0 hostname found
#               1 hostname not found
hostname::hosts::contains() {
    local hostname="$1"

    gawk -v target="$hostname" '
        $1 == "127.0.1.1" {
            for (i = 2; i <= NF; i++) {
                if ($i == target || index($i, target ".") == 1) {
                    found = 1
                }
            }
        }
        END { exit found ? 0 : 1 }
    '
}

# @type:        Orchestrator
# @description: Creates a persistent backup without replacing an existing original backup
# @params:      source_path Source configuration path (path) without a terminator
#               backup_path Backup path (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 backup exists or was created
#               1 source is missing or copy failed
hostname::file::backup() {
    local source_path="$1"
    local backup_path="$2"

    if [[ -f "$backup_path" ]]; then
        log_info "$(_ "hostname.backup.exists" "$backup_path")"
        return
    fi

    if [[ ! -f "$source_path" ]]; then
        log_error "$(_ "hostname.error.source_missing" "$source_path")"
        return 1
    fi

    local res
    if res=$(cp -pv "$source_path" "$backup_path" 2>&1); then
        log_info "$(_ "hostname.backup.created" "$res")"
    else
        log_error "$(_ "hostname.backup.failed" "$backup_path" "$res")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Backs up hostname configuration files
# @stdin:       None
# @stdout:      None
# @exit_code:   0 both backups exist
#               1 backup failed
hostname::file::backup_all() {
    hostname::file::backup "$HOSTNAME_FILE_PATH" "$HOSTNAME_BACKUP_PATH"
    hostname::file::backup "$HOSTS_FILE_PATH" "$HOSTS_BACKUP_PATH"
}

# @type:        Sink
# @description: Updates the hosts file with a new short hostname
# @params:      old_hostname Current short hostname (string) without a terminator
#               new_hostname New short hostname (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 hosts file updated
#               1 update failed
hostname::hosts::update() {
    local old_hostname="$1"
    local new_hostname="$2"
    local tmp

    tmp=$(mktemp)
    log_info "$(_ "hostname.info.update_hosts" "$HOSTS_FILE_PATH" "$old_hostname" "$new_hostname")"
    if hostname::hosts::replace "$old_hostname" "$new_hostname" < "$HOSTS_FILE_PATH" > "$tmp" && cat "$tmp" > "$HOSTS_FILE_PATH"; then
        printf '%s\0' "$tmp" | sys::file::delete
        log_info "$(_ "hostname.info.hosts_updated" "$HOSTS_FILE_PATH")"
    else
        printf '%s\0' "$tmp" | sys::file::delete || true
        log_error "$(_ "hostname.error.hosts_update" "$HOSTS_FILE_PATH")"
        return 1
    fi
}

# @type:        Validator
# @description: Checks whether BSSS hostname backups or cloud-init override exist
# @stdin:       None
# @stdout:      None
# @exit_code:   0 BSSS hostname configuration exists
#               1 no BSSS hostname configuration exists
hostname::state::is_configured() {
    [[ -f "$HOSTNAME_BACKUP_PATH" || -f "$HOSTS_BACKUP_PATH" || -f "$BSSS_CLOUD_INIT_HOSTNAME_FILE" ]]
}

# @type:        Orchestrator
# @description: Marks the system for reboot after a hostname change
# @stdin:       None
# @stdout:      None
# @exit_code:   0 reboot marker updated
#               1 marker update failed
hostname::reboot::mark_required() {
    local pkgs_file="${REBOOT_REQUIRED_FILE_PATH}.pkgs"

    if [[ ! -f "$REBOOT_REQUIRED_FILE_PATH" ]]; then
        if ! touch "$REBOOT_REQUIRED_FILE_PATH"; then
            log_error "$(_ "common.error.create_file" "$REBOOT_REQUIRED_FILE_PATH")"
            return 1
        fi
        log_info "$(_ "hostname.reboot.required" "$REBOOT_REQUIRED_FILE_PATH")"
    fi

    if [[ ! -f "$pkgs_file" ]] && ! touch "$pkgs_file"; then
        log_error "$(_ "common.error.create_file" "$pkgs_file")"
        return 1
    fi
    if ! grep -Fxq "$BSSS_HOSTNAME_REBOOT_PKG_NAME" "$pkgs_file"; then
        if ! printf '%s\n' "$BSSS_HOSTNAME_REBOOT_PKG_NAME" >> "$pkgs_file"; then
            log_error "$(_ "common.error.create_file" "$pkgs_file")"
            return 1
        fi
        log_info "$(_ "hostname.reboot.pkg_added" "$BSSS_HOSTNAME_REBOOT_PKG_NAME" "$pkgs_file")"
    fi

    log_attention "$(_ "hostname.reboot.warning")"
}

# @type:        Source
# @description: Reads the active short hostname
# @stdin:       None
# @stdout:      hostname\n
# @exit_code:   0 hostname read
#               $? hostname command failure
hostname::name::get_current() {
    hostname -s
}

# @type:        Orchestrator
# @description: Applies and verifies a new hostname with persistent backups
# @params:      new_hostname New short hostname (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 hostname configured
#               1 validation, update, or verification failed
hostname::orchestrator::configure() {
    local new_hostname="$1"
    local old_hostname

    if ! hostname::name::is_valid "$new_hostname"; then
        log_error "$(_ "hostname.error.invalid" "$new_hostname")"
        return 1
    fi

    old_hostname=$(hostname::name::get_current)
    hostname::file::backup_all
    hostname::cloud_init::ensure_preserved

    if [[ "$old_hostname" == "$new_hostname" ]]; then
        log_info "$(_ "hostname.info.already_set" "$new_hostname")"
        hostname::log::status
        return
    fi

    log_info "$(_ "common.log_command" "hostnamectl set-hostname $new_hostname")"
    hostnamectl set-hostname "$new_hostname"
    hostname::hosts::update "$old_hostname" "$new_hostname"

    if [[ "$(hostname::name::get_current)" != "$new_hostname" || "$(tr -d '[:space:]' < "$HOSTNAME_FILE_PATH")" != "$new_hostname" ]] \
        || ! hostname::hosts::contains "$new_hostname" < "$HOSTS_FILE_PATH"; then
        log_error "$(_ "hostname.error.verify" "$new_hostname")"
        return 1
    fi

    hostname::reboot::mark_required
    hostname::log::status
}

# @type:        Orchestrator
# @description: Restores one hostname configuration file and removes its backup
# @params:      backup_path Backup path (path) without a terminator
#               target_path Target configuration path (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 restored or no backup exists
#               1 restore failed
hostname::file::restore() {
    local backup_path="$1"
    local target_path="$2"

    if [[ ! -f "$backup_path" ]]; then
        log_info "$(_ "hostname.restore.missing_backup" "$backup_path")"
        return
    fi

    local res
    if res=$(cp -pv "$backup_path" "$target_path" 2>&1); then
        log_info "$(_ "hostname.restore.success" "$res")"
    else
        log_error "$(_ "hostname.restore.failed" "$target_path" "$res")"
        return 1
    fi

    printf '%s\0' "$backup_path" | sys::file::delete
}

# @type:        Orchestrator
# @description: Restores the original hostname files and removes the BSSS cloud-init override
# @stdin:       None
# @stdout:      None
# @exit_code:   0 original hostname restored or no configuration exists
#               1 restore or hostname update failed
hostname::orchestrator::restore() {
    if ! hostname::state::is_configured; then
        log_info "$(_ "hostname.restore.not_configured")"
        return
    fi

    local current_hostname
    current_hostname=$(hostname::name::get_current) || return 1

    hostname::file::restore "$HOSTNAME_BACKUP_PATH" "$HOSTNAME_FILE_PATH" || return 1
    hostname::file::restore "$HOSTS_BACKUP_PATH" "$HOSTS_FILE_PATH" || return 1
    if [[ -f "$BSSS_CLOUD_INIT_HOSTNAME_FILE" ]]; then
        printf '%s\0' "$BSSS_CLOUD_INIT_HOSTNAME_FILE" | sys::file::delete || return 1
    fi

    local restored_hostname
    restored_hostname=$(tr -d '[:space:]' < "$HOSTNAME_FILE_PATH") || return 1
    if [[ "$current_hostname" != "$restored_hostname" ]]; then
        log_info "$(_ "common.log_command" "hostnamectl set-hostname $restored_hostname")"
        hostnamectl set-hostname "$restored_hostname" || return 1
        hostname::reboot::mark_required || return 1
    fi

    hostname::log::status
}

# @type:        Sink
# @description: Logs active and persistent hostname configuration and cloud-init state
# @stdin:       None
# @stdout:      None
# @exit_code:   0 status logged
hostname::log::status() {
    local active fqdn file_hostname hosts_entries setting

    active=$(hostname::name::get_current)
    log_info "$(_ "hostname.check.active" "$active")"
    if fqdn=$(hostname -f 2>/dev/null); then
        log_info "$(_ "hostname.check.fqdn" "$fqdn")"
    else
        log_warn "$(_ "hostname.check.fqdn_failed")"
    fi

    if [[ -f "$HOSTNAME_FILE_PATH" ]]; then
        file_hostname=$(tr -d '[:space:]' < "$HOSTNAME_FILE_PATH")
        log_info "$(_ "hostname.check.hostname_file" "$HOSTNAME_FILE_PATH" "$file_hostname")"
    else
        log_warn "$(_ "hostname.check.file_missing" "$HOSTNAME_FILE_PATH")"
    fi

    if [[ -f "$HOSTS_FILE_PATH" ]]; then
        hosts_entries=$(gawk '$1 == "127.0.1.1" { print }' "$HOSTS_FILE_PATH")
        if [[ -n "$hosts_entries" ]]; then
            log_info "$(_ "hostname.check.hosts_file" "$HOSTS_FILE_PATH")"
            while IFS= read -r line; do
                log_info_simple_tab "$(_ "no_translate" "$line")"
            done <<< "$hosts_entries"
        else
            log_warn "$(_ "hostname.check.hosts_entry_missing" "$HOSTS_FILE_PATH")"
        fi
    else
        log_warn "$(_ "hostname.check.file_missing" "$HOSTS_FILE_PATH")"
    fi

    if ! hostname::cloud_init::is_installed; then
        log_info "$(_ "hostname.cloud_init.not_installed")"
        return
    fi

    log_info "$(_ "hostname.cloud_init.installed")"
    [[ ! -f "$CLOUD_INIT_DISABLED_FILE" ]] || log_info "$(_ "hostname.cloud_init.disabled" "$CLOUD_INIT_DISABLED_FILE")"
    setting=$(hostname::cloud_init::get_preserve_setting | tr -d '\0')
    if [[ "$setting" == "true" ]]; then
        log_info "$(_ "hostname.cloud_init.setting" "$setting")"
    else
        log_warn "$(_ "hostname.cloud_init.setting" "$setting")"
    fi
}
