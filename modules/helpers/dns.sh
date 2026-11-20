# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Source
# @description: Emits one machine-readable DNS issue
# @params:      issue_code Internal issue identifier (string) without a terminator
#               args Issue arguments (array), without terminators
# @stdin:       None
# @stdout:      issue_code<TAB>argument...\0
# @exit_code:   0 issue emitted
dns::issue::emit() {
    local issue_code="$1"
    shift

    printf '%s' "$issue_code"
    (( $# == 0 )) || printf '\t%s' "$@"
    printf '\0'
}

# @type:        Source
# @description: Reads the current operating system ID and version
# @stdin:       None
# @stdout:      os_id<TAB>version\n
# @exit_code:   0 release data read
#               1 release file unavailable
dns::os::get_release() {
    local ID="" VERSION_ID=""

    [[ -r "$OS_RELEASE_FILE_PATH" ]] || return 1
    source "$OS_RELEASE_FILE_PATH"
    printf '%s\t%s\n' "$ID" "$VERSION_ID"
}

# @type:        Validator
# @description: Checks whether the current Ubuntu release is supported by the DNS module
# @stdin:       None
# @stdout:      None
# @exit_code:   0 supported release
#               1 unsupported or unavailable release
dns::os::is_supported() {
    local id version
    local supported_pattern="^(${DNS_SUPPORTED_UBUNTU_VERSIONS})$"

    IFS=$'\t' read -r id version < <(dns::os::get_release) || return 1
    [[ "$id" == "ubuntu" && "$version" =~ $supported_pattern ]]
}

# @type:        Validator
# @description: Checks whether a resolver profile identifier is supported
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 supported profile
#               1 unsupported profile
dns::profile::is_valid() {
    [[ "$1" == "$DNS_PROFILE_GOOGLE_CLOUDFLARE" || "$1" == "$DNS_PROFILE_YANDEX_GOOGLE" ]]
}

# @type:        Source
# @description: Returns the systemd-resolved DNS server list for a profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      servers\0
# @exit_code:   0 profile resolved
#               1 unsupported profile
dns::profile::get_servers() {
    case "$1" in
        "$DNS_PROFILE_GOOGLE_CLOUDFLARE") printf '%s\0' "$DNS_SERVERS_GOOGLE_CLOUDFLARE" ;;
        "$DNS_PROFILE_YANDEX_GOOGLE") printf '%s\0' "$DNS_SERVERS_YANDEX_GOOGLE" ;;
        *) return 1 ;;
    esac
}

# @type:        Source
# @description: Returns endpoint and TLS hostname records for a resolver profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      ip<TAB>tls_hostname\0 (2 records)
# @exit_code:   0 profile resolved
#               1 unsupported profile
dns::profile::get_endpoints() {
    case "$1" in
        "$DNS_PROFILE_GOOGLE_CLOUDFLARE")
            printf '%s\t%s\0' "8.8.8.8" "dns.google"
            printf '%s\t%s\0' "1.1.1.1" "one.one.one.one"
            ;;
        "$DNS_PROFILE_YANDEX_GOOGLE")
            printf '%s\t%s\0' "77.88.8.8" "common.dot.dns.yandex.net"
            printf '%s\t%s\0' "8.8.8.8" "dns.google"
            ;;
        *) return 1 ;;
    esac
}

# @type:        Source
# @description: Returns the localized display name of a resolver profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      profile_name without a terminator
# @exit_code:   0 profile found
#               1 unsupported profile
dns::profile::get_name() {
    case "$1" in
        "$DNS_PROFILE_GOOGLE_CLOUDFLARE") printf '%s' "$(_ "dns.profile.google-cloudflare")" ;;
        "$DNS_PROFILE_YANDEX_GOOGLE") printf '%s' "$(_ "dns.profile.yandex-google")" ;;
        *) return 1 ;;
    esac
}

# @type:        Interactive
# @description: Displays resolver profiles and returns the selected identifier
# @stdin:       User input from the controlling terminal
# @stdout:      profile\0
# @exit_code:   0 profile selected
#               2 cancelled by user
dns::ui::select_profile() {
    log_info "$(_ "dns.auto.profile_question")"
    log_info_simple_tab "1. $(_ "dns.menu.google_cloudflare")"
    log_info_simple_tab "2. $(_ "dns.menu.yandex_google")"

    local choice
    choice=$(io::ask_value "$(_ "common.ask_select_action")" "1" "^[1-2]$" "1-2" | tr -d '\0') || return
    case "$choice" in
        1) printf '%s\0' "$DNS_PROFILE_GOOGLE_CLOUDFLARE" ;;
        2) printf '%s\0' "$DNS_PROFILE_YANDEX_GOOGLE" ;;
    esac
}

# @type:        Source
# @description: Reads one systemd unit property
# @params:      service Unit name (string) without a terminator
#               property Property name (string) without a terminator
# @stdin:       None
# @stdout:      property_value\n
# @exit_code:   0 property read
#               $? systemctl failure
dns::service::get_property() {
    systemctl show "$1" --property="$2" --value 2>/dev/null
}

# @type:        Validator
# @description: Checks whether the resolver preparation has any persistent artifact
# @stdin:       None
# @stdout:      None
# @exit_code:   0 one or more artifacts exist
#               1 no artifacts exist
dns::prepare::has_artifacts() {
    local path
    local -a paths=(
        "$DNS_PREPARE_DIR"
        "$DNS_PREPARE_STAGING_DIR"
        "$DNS_PREPARE_CLEANUP_DIR"
        "$DNS_PREPARE_TEMP_LINK"
    )

    for path in "${paths[@]}"; do
        [[ -e "$path" || -L "$path" ]] && return
    done
    return 1
}

# @type:        Orchestrator
# @description: Acquires the nonblocking resolver preparation lock
# @stdin:       None
# @stdout:      None
# @exit_code:   0 lock acquired
#               4 another DNS preparation operation is active
#               1 lock file could not be opened
dns::prepare::lock() {
    if [[ -n "$DNS_PREPARE_LOCK_FD" ]]; then
        return
    fi

    exec {DNS_PREPARE_LOCK_FD}> "$DNS_PREPARE_LOCK_FILE" || return 1
    if ! flock -n "$DNS_PREPARE_LOCK_FD"; then
        exec {DNS_PREPARE_LOCK_FD}>&-
        DNS_PREPARE_LOCK_FD=""
        log_warn "$(_ "dns.prepare.locked")"
        return 4
    fi
}

# @type:        Sink
# @description: Releases the resolver preparation lock
# @stdin:       None
# @stdout:      None
# @exit_code:   0 lock released or was not held
dns::prepare::unlock() {
    if [[ -n "$DNS_PREPARE_LOCK_FD" ]]; then
        exec {DNS_PREPARE_LOCK_FD}>&-
        DNS_PREPARE_LOCK_FD=""
    fi
}

# @type:        Validator
# @description: Checks whether the exact inactive networkd resolver baseline is present
# @stdin:       None
# @stdout:      None
# @exit_code:   0 exact baseline found
#               1 baseline differs or could not be inspected
dns::direct::is_baseline() {
    local load_state unit_file_state active_state sub_state
    local networkd_state networkd_sub_state network_manager_state

    load_state=$(dns::service::get_property "$DNS_RESOLVED_SERVICE" "LoadState") || return 1
    unit_file_state=$(dns::service::get_property "$DNS_RESOLVED_SERVICE" "UnitFileState") || return 1
    active_state=$(dns::service::get_property "$DNS_RESOLVED_SERVICE" "ActiveState") || return 1
    sub_state=$(dns::service::get_property "$DNS_RESOLVED_SERVICE" "SubState") || return 1
    networkd_state=$(dns::service::get_property "$DNS_NETWORKD_SERVICE" "ActiveState") || return 1
    networkd_sub_state=$(dns::service::get_property "$DNS_NETWORKD_SERVICE" "SubState") || return 1
    network_manager_state=$(dns::service::get_property "$DNS_NETWORK_MANAGER_SERVICE" "ActiveState") || return 1

    [[ "$load_state" == "loaded" &&
        "$unit_file_state" == "disabled" &&
        "$active_state" == "inactive" &&
        "$sub_state" == "dead" &&
        "$networkd_state" == "active" &&
        "$networkd_sub_state" == "running" &&
        "$network_manager_state" != "active" &&
        "$network_manager_state" != "activating" &&
        -f "$DNS_RESOLV_CONF_PATH" &&
        ! -L "$DNS_RESOLV_CONF_PATH" ]]
}

# @type:        Source
# @description: Classifies the resolver mode relevant to BSSS
# @stdin:       None
# @stdout:      resolved-stub|networkd-direct|interrupted|unsupported\0
# @exit_code:   0 mode classified
dns::resolver::get_mode() {
    local target

    if dns::prepare::has_artifacts; then
        printf 'interrupted\0'
    elif [[ -L "$DNS_RESOLV_CONF_PATH" ]] &&
        target=$(readlink -f "$DNS_RESOLV_CONF_PATH") &&
        [[ "$target" == "$DNS_RESOLVED_STUB_PATH" ]] &&
        systemctl is-active --quiet "$DNS_RESOLVED_SERVICE"; then
        printf 'resolved-stub\0'
    elif dns::direct::is_baseline; then
        printf 'networkd-direct\0'
    else
        printf 'unsupported\0'
    fi
}

# @type:        Validator
# @description: Validates a nameserver-only resolv.conf file
# @params:      path Resolver file path (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 valid nameserver-only file
#               1 empty, malformed, or unsupported file
#               $? gawk failure
dns::direct::content_is_supported() {
    gawk '
        function ipv4(value, parts, count, i) {
            count = split(value, parts, ".")
            if (count != 4) {
                return 0
            }
            for (i = 1; i <= 4; i++) {
                if (parts[i] !~ /^(0|[1-9][0-9]{0,2})$/ ||
                    parts[i] + 0 > 255) {
                    return 0
                }
            }
            return 1
        }
        function hextets(value, parts, count, i) {
            if (value == "") {
                return 0
            }
            count = split(value, parts, ":")
            for (i = 1; i <= count; i++) {
                if (parts[i] !~ /^[0-9A-Fa-f]{1,4}$/) {
                    return -1
                }
            }
            return count
        }
        function ipv6(value, separator, left, right, left_count, right_count) {
            if (value !~ /^[0-9A-Fa-f:]+$/ || value !~ /:/ ||
                value ~ /%/ || value ~ /::.*::/) {
                return 0
            }
            separator = index(value, "::")
            if (separator == 0) {
                return hextets(value) == 8
            }
            left = substr(value, 1, separator - 1)
            right = substr(value, separator + 2)
            left_count = left == "" ? 0 : hextets(left)
            right_count = right == "" ? 0 : hextets(right)
            return left_count >= 0 && right_count >= 0 &&
                left_count + right_count < 8
        }
        /^[[:space:]]*($|#)/ {
            next
        }
        {
            if (NF != 2 || $1 != "nameserver" ||
                !(ipv4($2) || ipv6($2))) {
                invalid = 1
                exit
            }
            found = 1
        }
        END { exit found && !invalid ? 0 : 1 }
    ' "$1"
}

# @type:        Validator
# @description: Validates the direct resolver file object and content
# @stdin:       None
# @stdout:      None
# @exit_code:   0 supported object and content
#               4 unsupported or ambiguous resolver file
dns::direct::file_is_supported() {
    local uid gid links type mount_target attributes

    [[ -f "$DNS_RESOLV_CONF_PATH" && ! -L "$DNS_RESOLV_CONF_PATH" ]] || return 4
    IFS=$'\t' read -r uid gid links type < <(
        stat -c $'%u\t%g\t%h\t%F' "$DNS_RESOLV_CONF_PATH"
    ) || return 4
    [[ "$uid" == "0" && "$gid" == "0" && "$links" == "1" && "$type" == "regular file" ]] || return 4

    mount_target=$(findmnt -n -T "$DNS_RESOLV_CONF_PATH" -o TARGET) || return 4
    [[ "$mount_target" != "$DNS_RESOLV_CONF_PATH" ]] || return 4

    attributes=$(lsattr -d "$DNS_RESOLV_CONF_PATH" 2>/dev/null) || return 4
    [[ "${attributes%% *}" != *i* ]] || return 4
    dns::direct::content_is_supported "$DNS_RESOLV_CONF_PATH" || return 4
}

# @type:        Source
# @description: Emits the resolver file identity used for the final source recheck
# @stdin:       None
# @stdout:      device<TAB>inode<TAB>size<TAB>uid<TAB>gid<TAB>mode<TAB>sha256\0
# @exit_code:   0 fingerprint emitted
#               $? stat or sha256sum failure
dns::direct::fingerprint() {
    local metadata hash

    metadata=$(stat -c $'%d\t%i\t%s\t%u\t%g\t%a' "$DNS_RESOLV_CONF_PATH") || return 1
    hash=$(sha256sum "$DNS_RESOLV_CONF_PATH") || return 1
    printf '%s\t%s\0' "$metadata" "${hash%% *}"
}

# @type:        Validator
# @description: Validates or creates the private BSSS state directory
# @stdin:       None
# @stdout:      None
# @exit_code:   0 secure state directory available
#               1 creation or validation failed
dns::prepare::ensure_state_dir() {
    local uid gid mode mode_value

    if [[ ! -e "$BSSS_STATE_DIR" && ! -L "$BSSS_STATE_DIR" ]]; then
        mkdir -m 700 "$BSSS_STATE_DIR" || return 1
    fi
    [[ -d "$BSSS_STATE_DIR" && ! -L "$BSSS_STATE_DIR" ]] || return 1

    IFS=$'\t' read -r uid gid mode < <(stat -c $'%u\t%g\t%a' "$BSSS_STATE_DIR") || return 1
    mode_value=$((8#$mode))
    [[ "$uid" == "0" && "$gid" == "0" ]] && (( (mode_value & 8#022) == 0 ))
}

# @type:        Source
# @description: Renders the resolver preparation state file
# @params:      profile Resolver profile identifier (string) without a terminator
#               hash Resolver backup SHA-256 (string) without a terminator
# @stdin:       None
# @stdout:      state content (text\n)
# @exit_code:   0 state rendered
#               1 invalid profile or hash
dns::prepare::render_state() {
    local profile="$1"
    local hash="$2"

    dns::profile::is_valid "$profile" || return 1
    [[ "$hash" =~ ^[0-9a-f]{64}$ ]] || return 1
    printf '# %s\nschema\t1\nprofile\t%s\nsha256\t%s\n' "$BSSS_MARKER_COMMENT" "$profile" "$hash"
}

# @type:        Source
# @description: Validates and reads a complete resolver preparation bundle
# @params:      directory Bundle directory (path) without a terminator
# @stdin:       None
# @stdout:      profile<TAB>sha256\0
# @exit_code:   0 valid complete bundle
#               1 invalid or incomplete bundle
dns::prepare::read_bundle() {
    local directory="$1"
    local state="${directory}/state"
    local backup="${directory}/resolv.conf"
    local uid gid mode links type profile hash actual_hash

    [[ -d "$directory" && ! -L "$directory" ]] || return 1
    IFS=$'\t' read -r uid gid mode < <(stat -c $'%u\t%g\t%a' "$directory") || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$mode" == "700" ]] || return 1

    [[ -f "$state" && ! -L "$state" ]] || return 1
    IFS=$'\t' read -r uid gid mode links type < <(stat -c $'%u\t%g\t%a\t%h\t%F' "$state") || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$mode" == "600" &&
        "$links" == "1" && "$type" == "regular file" ]] || return 1

    IFS=$'\t' read -r profile hash < <(
        gawk -v marker="# ${BSSS_MARKER_COMMENT}" '
            NR == 1 { valid = $0 == marker; next }
            NR == 2 { valid = valid && $0 == "schema\t1"; next }
            NR == 3 && $1 == "profile" { profile = $2; next }
            NR == 4 && $1 == "sha256" { hash = $2; next }
            { valid = 0 }
            END {
                if (valid && NR == 4 &&
                    (profile == "google-cloudflare" || profile == "yandex-google") &&
                    hash ~ /^[0-9a-f]{64}$/) {
                    print profile "\t" hash
                    exit 0
                }
                exit 1
            }
        ' "$state"
    ) || return 1

    [[ -f "$backup" && ! -L "$backup" ]] || return 1
    IFS=$'\t' read -r uid gid links type < <(stat -c $'%u\t%g\t%h\t%F' "$backup") || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$links" == "1" && "$type" == "regular file" ]] || return 1
    actual_hash=$(sha256sum "$backup") || return 1
    [[ "${actual_hash%% *}" == "$hash" ]] || return 1

    printf '%s\t%s\0' "$profile" "$hash"
}

# @type:        Validator
# @description: Checks whether a partial staging or cleanup directory is safely removable
# @params:      directory Bundle directory (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 only valid expected entries are present
#               1 foreign metadata or entries found
dns::prepare::partial_is_owned() {
    local directory="$1"
    local uid gid mode entry name links type
    local -a entries=()

    [[ -d "$directory" && ! -L "$directory" ]] || return 1
    IFS=$'\t' read -r uid gid mode < <(stat -c $'%u\t%g\t%a' "$directory") || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$mode" == "700" ]] || return 1

    while IFS= read -r -d '' entry; do
        entries+=("$entry")
    done < <(
        shopt -s nullglob dotglob
        for entry in "$directory"/*; do
            printf '%s\0' "$entry"
        done
    )
    for entry in "${entries[@]}"; do
        name="${entry##*/}"
        [[ "$name" == "state" || "$name" == "resolv.conf" ]] || return 1
        [[ -f "$entry" && ! -L "$entry" ]] || return 1
        IFS=$'\t' read -r uid gid mode links type < <(stat -c $'%u\t%g\t%a\t%h\t%F' "$entry") || return 1
        [[ "$uid" == "0" && "$gid" == "0" && "$links" == "1" && "$type" == regular*file ]] || return 1
        [[ "$name" != "state" || "$mode" == "600" ]] || return 1
    done
}

# @type:        Sink
# @description: Removes an owned partial staging or cleanup directory
# @params:      directory Bundle directory (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 exact owned entries removed
#               1 foreign state or deletion failure
dns::prepare::remove_partial() {
    local directory="$1"

    dns::prepare::partial_is_owned "$directory" || return 1
    [[ ! -e "${directory}/state" ]] || rm -- "${directory}/state" || return 1
    [[ ! -e "${directory}/resolv.conf" ]] || rm -- "${directory}/resolv.conf" || return 1
    rmdir -- "$directory"
}

# @type:        Sink
# @description: Removes the exact owned temporary resolv.conf symlink
# @stdin:       None
# @stdout:      None
# @exit_code:   0 owned link removed or absent
#               1 foreign object found or deletion failed
dns::prepare::remove_temp_link() {
    if [[ ! -e "$DNS_PREPARE_TEMP_LINK" && ! -L "$DNS_PREPARE_TEMP_LINK" ]]; then
        return
    fi
    [[ -L "$DNS_PREPARE_TEMP_LINK" &&
        "$(readlink "$DNS_PREPARE_TEMP_LINK")" == "$DNS_RESOLVED_STUB_PATH" ]] || return 1
    rm -- "$DNS_PREPARE_TEMP_LINK"
}

# @type:        Orchestrator
# @description: Publishes the short-lived resolver preparation bundle
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 durable bundle published
#               1 creation, validation, flush, or rename failed
dns::prepare::create_bundle() {
    local profile="$1"
    local hash

    dns::prepare::ensure_state_dir || return 1
    dns::prepare::has_artifacts && return 1

    (
        umask 077
        mkdir -m 700 "$DNS_PREPARE_STAGING_DIR" || exit 1
        cp -a -- "$DNS_RESOLV_CONF_PATH" "${DNS_PREPARE_STAGING_DIR}/resolv.conf" || exit 1
        hash=$(sha256sum "${DNS_PREPARE_STAGING_DIR}/resolv.conf") || exit 1
        dns::prepare::render_state "$profile" "${hash%% *}" > "${DNS_PREPARE_STAGING_DIR}/state" || exit 1
        chown root:root "${DNS_PREPARE_STAGING_DIR}/state" || exit 1
        chmod 600 "${DNS_PREPARE_STAGING_DIR}/state" || exit 1
        dns::prepare::read_bundle "$DNS_PREPARE_STAGING_DIR" >/dev/null || exit 1
        sync -f "$DNS_PREPARE_STAGING_DIR" || exit 1
        mv -T "$DNS_PREPARE_STAGING_DIR" "$DNS_PREPARE_DIR" || exit 1
        sync -f "$BSSS_STATE_DIR"
    ) || return 1

    log_info "$(_ "dns.prepare.bundle_created" "$DNS_PREPARE_DIR")"
}

# @type:        Sink
# @description: Removes a complete resolver preparation bundle after a validated outcome
# @stdin:       None
# @stdout:      None
# @exit_code:   0 bundle removed
#               1 validation, rename, flush, or deletion failed
dns::prepare::cleanup_bundle() {
    dns::prepare::read_bundle "$DNS_PREPARE_DIR" >/dev/null || return 1
    [[ ! -e "$DNS_PREPARE_CLEANUP_DIR" && ! -L "$DNS_PREPARE_CLEANUP_DIR" ]] || return 1
    mv -T "$DNS_PREPARE_DIR" "$DNS_PREPARE_CLEANUP_DIR" || return 1
    sync -f "$BSSS_STATE_DIR" || return 1
    dns::prepare::remove_partial "$DNS_PREPARE_CLEANUP_DIR" || return 1
    log_info "$(_ "dns.prepare.bundle_removed" "$DNS_PREPARE_DIR")"
}

# @type:        Source
# @description: Renders the BSSS systemd-resolved drop-in for a profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      resolved.conf content (text\n)
# @exit_code:   0 configuration rendered
#               1 unsupported profile
dns::config::render() {
    local servers

    servers=$(dns::profile::get_servers "$1" | tr -d '\0') || return 1
    cat << EOF
# $BSSS_MARKER_COMMENT
[Resolve]
DNS=
DNS=$servers
FallbackDNS=
Domains=
Domains=~.
DNSOverTLS=yes
DNSSEC=no
LLMNR=no
MulticastDNS=no
EOF
}

# @type:        Validator
# @description: Checks whether a regular file is owned by BSSS
# @params:      path File path (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 regular BSSS-owned file
#               1 missing, linked, or foreign file
dns::config::is_owned() {
    local path="$1"

    [[ -f "$path" && ! -L "$path" ]] && grep -Fxq "# $BSSS_MARKER_COMMENT" "$path"
}

# @type:        Filter
# @description: Resolves managed settings from concatenated resolved.conf files
# @stdin:       systemd-analyze cat-config output (text\n)
# @stdout:      setting<TAB>value\n
# @exit_code:   0 settings parsed
#               $? gawk failure
dns::config::parse_effective() {
    gawk '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }
        function append(current, value) {
            return current == "" ? value : current " " value
        }
        BEGIN {
            section = ""
            keys[1] = "DNS"
            keys[2] = "FallbackDNS"
            keys[3] = "Domains"
            keys[4] = "DNSOverTLS"
            keys[5] = "DNSSEC"
            keys[6] = "LLMNR"
            keys[7] = "MulticastDNS"
        }
        /^[[:space:]]*#/ || /^[[:space:]]*$/ {
            next
        }
        /^[[:space:]]*\[/ {
            section = $0
            gsub(/[[:space:]]/, "", section)
            next
        }
        section == "[Resolve]" {
            separator = index($0, "=")
            if (separator == 0) {
                next
            }
            key = trim(substr($0, 1, separator - 1))
            value = trim(substr($0, separator + 1))
            if (key == "DNS" || key == "FallbackDNS" || key == "Domains") {
                seen[key] = 1
                if (value == "") {
                    values[key] = ""
                } else {
                    values[key] = append(values[key], value)
                }
            } else if (key == "DNSOverTLS" || key == "DNSSEC" || key == "LLMNR" || key == "MulticastDNS") {
                seen[key] = 1
                values[key] = value
            }
        }
        END {
            for (i = 1; i <= 7; i++) {
                key = keys[i]
                print key "\t" (seen[key] ? values[key] : "__unset__")
            }
        }
    '
}

# @type:        Source
# @description: Reads and parses effective systemd-resolved configuration
# @stdin:       None
# @stdout:      setting<TAB>value\n
# @exit_code:   0 configuration parsed
#               $? systemd-analyze or parser failure
dns::config::get_effective() {
    systemd-analyze cat-config systemd/resolved.conf | dns::config::parse_effective
}

# @type:        Source
# @description: Returns the recognized resolver profile from effective configuration
# @stdin:       None
# @stdout:      profile\0
# @exit_code:   0 profile recognized
#               1 configuration unavailable or profile unknown
dns::status::get_profile() {
    local effective key value

    effective=$(dns::config::get_effective) || return 1
    while IFS=$'\t' read -r key value; do
        [[ "$key" == "DNS" ]] || continue
        case "$value" in
            "$DNS_SERVERS_GOOGLE_CLOUDFLARE") printf '%s\0' "$DNS_PROFILE_GOOGLE_CLOUDFLARE"; return ;;
            "$DNS_SERVERS_YANDEX_GOOGLE") printf '%s\0' "$DNS_PROFILE_YANDEX_GOOGLE"; return ;;
            *) return 1 ;;
        esac
    done <<< "$effective"
    return 1
}

# @type:        Validator
# @description: Checks whether the standard systemd-resolved stub is listening
# @stdin:       None
# @stdout:      None
# @exit_code:   0 stub is listening on 127.0.0.53:53
#               1 stub is not listening
dns::runtime::stub_is_listening() {
    ss -H -lntu | gawk '
        $5 ~ /^127\.0\.0\.53(%[^:]*)?:53$/ && $1 == "udp" {
            udp = 1
        }
        $5 ~ /^127\.0\.0\.53(%[^:]*)?:53$/ && $1 == "tcp" {
            tcp = 1
        }
        END { exit udp && tcp ? 0 : 1 }
    '
}

# @type:        Source
# @description: Lists port 53 listeners other than supported systemd-resolved stubs
# @stdin:       None
# @stdout:      address\0 (0..N)
# @exit_code:   0 listeners inspected
#               $? ss or gawk failure
dns::runtime::local_resolvers() {
    ss -H -lntu | gawk '
        BEGIN { ORS = "\0" }
        $5 ~ /:53$/ &&
        $5 !~ /^127\.0\.0\.53(%[^:]*)?:53$/ &&
        $5 !~ /^127\.0\.0\.54(%[^:]*)?:53$/ {
            addresses[$5] = 1
        }
        END {
            for (address in addresses) {
                print address
            }
        }
    '
}

# @type:        Filter
# @description: Finds per-link DNS route domains that can bypass the global root route
# @stdin:       resolvectl domain output (text\n)
# @stdout:      route_domain<TAB>link<TAB>domain\0 (0..N)
# @exit_code:   0 parsed
#               $? gawk failure
dns::runtime::route_issues() {
    gawk '
        BEGIN { ORS = "\0" }
        /^Link [0-9]+ \(/ {
            separator = index($0, ":")
            if (separator == 0) {
                next
            }
            link = substr($0, 1, separator - 1)
            sub(/^Link [0-9]+ \(/, "", link)
            sub(/\)$/, "", link)
            domains = substr($0, separator + 1)
            count = split(domains, values, /[[:space:]]+/)
            for (i = 1; i <= count; i++) {
                if (values[i] != "") {
                    print "route_domain\t" link "\t" values[i]
                }
            }
        }
    '
}

# @type:        Source
# @description: Returns the Global value from a resolvectl property command
# @params:      property Resolvectl property command (string) without a terminator
# @stdin:       None
# @stdout:      value\0
# @exit_code:   0 value parsed
#               1 unsupported property or missing Global row
#               $? resolvectl or gawk failure
dns::runtime::get_global() {
    local property="$1"
    local output

    case "$property" in
        dns|domain|dnsovertls) ;;
        *) return 1 ;;
    esac

    if ! output=$(resolvectl --no-pager "$property" 2>&1); then
        return 1
    fi

    gawk '
        BEGIN { ORS = "\0" }
        /^Global:/ {
            value = substr($0, index($0, ":") + 1)
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            print value
            found = 1
            exit
        }
        END { exit found ? 0 : 1 }
    ' <<< "$output"
}

# @type:        Source
# @description: Emits all reasons why supported DNS protection is not confirmed
# @stdin:       None
# @stdout:      issue_code<TAB>argument...\0 (0..N)
# @exit_code:   0 inspection completed
#               $? unexpected command or parser failure
dns::status::issues() {
    local command missing=0
    local -a commands=(systemctl systemd-analyze resolvectl readlink ss gawk)

    for command in "${commands[@]}"; do
        if ! command -v "$command" >/dev/null 2>&1; then
            dns::issue::emit "missing_command" "$command"
            missing=1
        fi
    done
    (( missing == 0 )) || return 0

    local release="unknown"
    if release=$(dns::os::get_release); then
        if ! dns::os::is_supported; then
            dns::issue::emit "unsupported_os" "${release//$'\t'/ }"
        fi
    else
        dns::issue::emit "unsupported_os" "unknown"
    fi

    local resolved_active=1
    if ! systemctl is-active --quiet "$DNS_RESOLVED_SERVICE"; then
        dns::issue::emit "resolved_inactive"
        resolved_active=0
    fi

    local resolv_target="unavailable"
    if resolv_target=$(readlink -f "$DNS_RESOLV_CONF_PATH") && [[ "$resolv_target" == "$DNS_RESOLVED_STUB_PATH" ]]; then
        :
    else
        dns::issue::emit "resolv_conf" "$resolv_target"
    fi

    if ! dns::runtime::stub_is_listening; then
        dns::issue::emit "stub_inactive"
    fi

    local listener
    while IFS= read -r -d '' listener; do
        dns::issue::emit "local_resolver" "$listener"
    done < <(dns::runtime::local_resolvers)

    local effective profile=""
    if effective=$(dns::config::get_effective 2>/dev/null); then
        local -A settings=()
        local key value
        while IFS=$'\t' read -r key value; do
            settings["$key"]="$value"
        done <<< "$effective"

        case "${settings[DNS]-__unset__}" in
            "$DNS_SERVERS_GOOGLE_CLOUDFLARE") profile="$DNS_PROFILE_GOOGLE_CLOUDFLARE" ;;
            "$DNS_SERVERS_YANDEX_GOOGLE") profile="$DNS_PROFILE_YANDEX_GOOGLE" ;;
            *) dns::issue::emit "profile_unknown" "${settings[DNS]-__unset__}" ;;
        esac
        [[ "${settings[FallbackDNS]-__unset__}" == "" ]] || \
            dns::issue::emit "fallback_dns" "${settings[FallbackDNS]-__unset__}"
        [[ "${settings[Domains]-__unset__}" == "~." ]] || \
            dns::issue::emit "domains" "${settings[Domains]-__unset__}"
        [[ "${settings[DNSOverTLS]-__unset__}" == "yes" ]] || \
            dns::issue::emit "dot_mode" "${settings[DNSOverTLS]-__unset__}"
        [[ "${settings[DNSSEC]-__unset__}" == "no" ]] || \
            dns::issue::emit "dnssec" "${settings[DNSSEC]-__unset__}"
        [[ "${settings[LLMNR]-__unset__}" == "no" ]] || \
            dns::issue::emit "llmnr" "${settings[LLMNR]-__unset__}"
        [[ "${settings[MulticastDNS]-__unset__}" == "no" ]] || \
            dns::issue::emit "multicast_dns" "${settings[MulticastDNS]-__unset__}"
    else
        dns::issue::emit "effective_unavailable"
    fi

    (( resolved_active == 1 )) || return 0

    local runtime_unavailable=0
    local runtime_dns expected_runtime_dns
    if [[ -n "$profile" ]]; then
        expected_runtime_dns=$(dns::profile::get_servers "$profile" | tr -d '\0')
        if IFS= read -r -d '' runtime_dns < <(dns::runtime::get_global "dns"); then
            # systemd 249 can omit resolved.conf global values from this command.
            [[ -z "$runtime_dns" || "$runtime_dns" == "$expected_runtime_dns" ]] ||
                dns::issue::emit "runtime_dns" "${runtime_dns:-__unset__}"
        else
            runtime_unavailable=1
        fi
    fi

    local runtime_domains
    if IFS= read -r -d '' runtime_domains < <(dns::runtime::get_global "domain"); then
        [[ -z "$runtime_domains" || "$runtime_domains" == "~." ]] ||
            dns::issue::emit "runtime_domains" "${runtime_domains:-__unset__}"
    else
        runtime_unavailable=1
    fi

    local runtime_dot
    if IFS= read -r -d '' runtime_dot < <(dns::runtime::get_global "dnsovertls"); then
        [[ -z "$runtime_dot" || "$runtime_dot" == "yes" ]] ||
            dns::issue::emit "runtime_dot" "${runtime_dot:-__unset__}"
    else
        runtime_unavailable=1
    fi

    local domains
    if domains=$(resolvectl --no-pager domain 2>/dev/null); then
        dns::runtime::route_issues <<< "$domains"
    else
        runtime_unavailable=1
    fi

    if (( runtime_unavailable == 1 )); then
        dns::issue::emit "runtime_unavailable"
    fi
}

# @type:        Validator
# @description: Checks whether the supported protected DNS state is confirmed
# @stdin:       None
# @stdout:      None
# @exit_code:   0 protected state confirmed
#               1 one or more issues found
#               $? inspection or parser failure
dns::status::is_protected() {
    dns::status::issues | gawk '
        BEGIN { RS = "\0" }
        NF { found = 1 }
        END { exit found ? 1 : 0 }
    '
}

# @type:        Source
# @description: Formats an effective DNS setting value for user-facing output
# @params:      value Raw setting value (string) without a terminator
# @stdin:       None
# @stdout:      display_value\n
# @exit_code:   0 value formatted
dns::log::display_value() {
    if [[ "$1" == "__unset__" ]]; then
        printf '%s\n' "$(_ "dns.value.unset")"
    else
        printf '%s\n' "$1"
    fi
}

# @type:        Sink
# @description: Renders machine-readable DNS issue records as tabbed messages
# @stdin:       issue_code<TAB>argument...\0 (0..N)
# @stdout:      None
# @exit_code:   0 issues rendered
dns::log::issues() {
    local record code arg1 arg2

    while IFS= read -r -d '' record; do
        IFS=$'\t' read -r code arg1 arg2 <<< "$record"
        case "$code" in
            profile_unknown|fallback_dns|domains|dot_mode|dnssec|llmnr|multicast_dns|runtime_dns|runtime_domains|runtime_dot)
                arg1=$(dns::log::display_value "$arg1")
                ;;
        esac
        case "$code" in
            missing_command)       log_info_simple_tab "$(_ "dns.issue.missing_command" "$arg1")" ;;
            unsupported_os)        log_info_simple_tab "$(_ "dns.issue.unsupported_os" "$arg1")" ;;
            resolved_inactive)     log_info_simple_tab "$(_ "dns.issue.resolved_inactive")" ;;
            resolv_conf)           log_info_simple_tab "$(_ "dns.issue.resolv_conf" "$arg1")" ;;
            stub_inactive)         log_info_simple_tab "$(_ "dns.issue.stub_inactive")" ;;
            local_resolver)        log_info_simple_tab "$(_ "dns.issue.local_resolver" "$arg1")" ;;
            effective_unavailable) log_info_simple_tab "$(_ "dns.issue.effective_unavailable")" ;;
            profile_unknown)       log_info_simple_tab "$(_ "dns.issue.profile_unknown" "$arg1")" ;;
            fallback_dns)          log_info_simple_tab "$(_ "dns.issue.fallback_dns" "$arg1")" ;;
            domains)               log_info_simple_tab "$(_ "dns.issue.domains" "$arg1")" ;;
            dot_mode)              log_info_simple_tab "$(_ "dns.issue.dot_mode" "$arg1")" ;;
            dnssec)                log_info_simple_tab "$(_ "dns.issue.dnssec" "$arg1")" ;;
            llmnr)                 log_info_simple_tab "$(_ "dns.issue.llmnr" "$arg1")" ;;
            multicast_dns)         log_info_simple_tab "$(_ "dns.issue.multicast_dns" "$arg1")" ;;
            route_domain)          log_info_simple_tab "$(_ "dns.issue.route_domain" "$arg1" "$arg2")" ;;
            runtime_dns)           log_info_simple_tab "$(_ "dns.issue.runtime_dns" "$arg1")" ;;
            runtime_domains)       log_info_simple_tab "$(_ "dns.issue.runtime_domains" "$arg1")" ;;
            runtime_dot)           log_info_simple_tab "$(_ "dns.issue.runtime_dot" "$arg1")" ;;
            runtime_unavailable)   log_info_simple_tab "$(_ "dns.issue.runtime_unavailable")" ;;
            *)                     log_info_simple_tab "$(_ "dns.issue.unknown" "$code")" ;;
        esac
    done
}

# @type:        Sink
# @description: Logs the effective settings from the BSSS-owned DNS configuration
# @stdin:       None
# @stdout:      None
# @exit_code:   0 configuration logged or absent
#               $? inspection or parser failure
dns::log::bsss_config() {
    local name value

    if ! dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
        log_info "$(_ "dns.config.bsss_absent" "$BSSS_DNS_CONFIG_FILE")"
        return
    fi

    log_info "$(_ "dns.config.bsss_found")"
    dns::config::parse_effective < "$BSSS_DNS_CONFIG_FILE" |
        while IFS=$'\t' read -r name value; do
            [[ "$value" == "__unset__" ]] && continue
            log_info_simple_tab "$(_ "no_translate" "${BSSS_DNS_CONFIG_FILE}:${name}=${value}")"
        done
}

# @type:        Sink
# @description: Logs the supported protected DNS state or its detected issues
# @stdin:       None
# @stdout:      None
# @exit_code:   0 status logged
#               $? inspection or parser failure
dns::log::status() {
    local profile

    if dns::status::is_protected; then
        profile=$(dns::status::get_profile | tr -d '\0')
        case "$profile" in
            "$DNS_PROFILE_GOOGLE_CLOUDFLARE") log_info "$(_ "dns.status.protected_google_cloudflare")" ;;
            "$DNS_PROFILE_YANDEX_GOOGLE") log_info "$(_ "dns.status.protected_yandex_google")" ;;
        esac
        dns::log::bsss_config
        return
    fi

    log_warn "$(_ "dns.status.unconfirmed")"
    dns::status::issues | dns::log::issues
}

# @type:        Validator
# @description: Checks whether a resolved.conf file actively sets BSSS-managed values
# @params:      path resolved.conf path (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 one or more managed settings found
#               1 no managed settings found
#               $? gawk failure
dns::config::has_managed_setting() {
    gawk '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ {
            next
        }
        /^[[:space:]]*\[/ {
            section = $0
            gsub(/[[:space:]]/, "", section)
            next
        }
        section == "[Resolve]" &&
        /^[[:space:]]*(DNS|FallbackDNS|Domains|DNSOverTLS|DNSSEC|LLMNR|MulticastDNS)[[:space:]]*=/ {
            found = 1
            exit
        }
        END { exit found ? 0 : 1 }
    ' "$1"
}

# @type:        Source
# @description: Lists later-sorting foreign drop-ins that can override BSSS DNS values
# @stdin:       None
# @stdout:      path\0 (0..N)
# @exit_code:   0 search completed
dns::config::late_conflicts() {
    (
        shopt -s nullglob
        local LC_ALL=C
        local dir path name
        local -a dirs=(
            "/usr/lib/systemd/resolved.conf.d"
            "/usr/local/lib/systemd/resolved.conf.d"
            "/lib/systemd/resolved.conf.d"
            "/run/systemd/resolved.conf.d"
            "/etc/systemd/resolved.conf.d"
        )

        for dir in "${dirs[@]}"; do
            [[ -d "$dir" ]] || continue
            for path in "$dir"/*.conf; do
                name=$(basename "$path")
                [[ "$name" > "$BSSS_DNS_CONFIG_FILE_NAME" ]] || continue
                dns::config::has_managed_setting "$path" && printf '%s\0' "$path"
            done
        done
    )
}

# @type:        Orchestrator
# @description: Checks common system requirements for safe DNS mutation
# @stdin:       None
# @stdout:      None
# @exit_code:   0 system is supported
#               4 preconfiguration required
dns::preflight::check_system() {
    local command
    local -a commands=(systemctl systemd-analyze resolvectl readlink ss gawk openssl timeout mktemp mv cp cmp chown chmod mkdir)

    if ! dns::os::is_supported; then
        local release="unknown"
        release=$(dns::os::get_release 2>/dev/null) || true
        log_warn "$(_ "dns.preflight.unsupported_os" "${release//$'\t'/ }")"
        return 4
    fi

    for command in "${commands[@]}"; do
        if ! command -v "$command" >/dev/null 2>&1; then
            log_warn "$(_ "dns.preflight.missing_command" "$command")"
            return 4
        fi
    done

    local load_state
    load_state=$(systemctl show "$DNS_RESOLVED_SERVICE" --property=LoadState --value 2>/dev/null) || true
    if [[ "$load_state" != "loaded" ]] || ! systemctl is-active --quiet "$DNS_RESOLVED_SERVICE"; then
        log_warn "$(_ "dns.preflight.resolved_unavailable")"
        return 4
    fi

    local resolv_target="unavailable"
    if [[ ! -L "$DNS_RESOLV_CONF_PATH" ]] ||
        ! resolv_target=$(readlink -f "$DNS_RESOLV_CONF_PATH") ||
        [[ "$resolv_target" != "$DNS_RESOLVED_STUB_PATH" ]]; then
        log_warn "$(_ "dns.preflight.resolv_conf" "$resolv_target")"
        return 4
    fi

    if ! dns::runtime::stub_is_listening; then
        log_warn "$(_ "dns.preflight.stub_inactive")"
        return 4
    fi

    local listener
    if IFS= read -r -d '' listener < <(dns::runtime::local_resolvers); then
        log_warn "$(_ "dns.preflight.local_resolver" "$listener")"
        return 4
    fi

    if [[ -L "$DNS_RESOLVED_CONFIG_DIR" ]] ||
        [[ -e "$DNS_RESOLVED_CONFIG_DIR" && ! -d "$DNS_RESOLVED_CONFIG_DIR" ]]; then
        log_warn "$(_ "dns.preflight.config_dir" "$DNS_RESOLVED_CONFIG_DIR")"
        return 4
    fi
}

# @type:        Orchestrator
# @description: Checks BSSS target ownership and transient rollback state
# @params:      require_target Whether a BSSS target must exist (bool) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 target state is safe
#               4 preconfiguration required
dns::preflight::check_target() {
    local require_target="$1"

    if [[ -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]]; then
        log_warn "$(_ "dns.preflight.stale_backup" "$BSSS_DNS_ROLLBACK_FILE")"
        return 4
    fi

    if [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]]; then
        if ! dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
            log_warn "$(_ "dns.preflight.foreign_target" "$BSSS_DNS_CONFIG_FILE")"
            return 4
        fi
    elif [[ "$require_target" == "true" ]]; then
        log_warn "$(_ "dns.preflight.target_missing" "$BSSS_DNS_CONFIG_FILE")"
        return 4
    fi
}

# @type:        Validator
# @description: Validates TLS reachability and certificate identity for one DoT endpoint
# @params:      ip Resolver IPv4 address (string) without a terminator
#               tls_hostname TLS server name (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 endpoint validated
#               1 connection or certificate validation failed
dns::endpoint::check() {
    local ip="$1"
    local tls_hostname="$2"
    local command_text="timeout ${DNS_ENDPOINT_TIMEOUT_SECONDS}s openssl s_client -connect ${ip}:853 -servername ${tls_hostname} -verify_hostname ${tls_hostname} -verify_return_error -brief"
    local output

    log_info "$(_ "dns.endpoint.check" "$ip" "$tls_hostname")"
    log_info "$(_ "common.log_command" "$command_text")"
    if output=$(timeout "${DNS_ENDPOINT_TIMEOUT_SECONDS}s" openssl s_client \
        -connect "${ip}:853" \
        -servername "$tls_hostname" \
        -verify_hostname "$tls_hostname" \
        -verify_return_error \
        -brief </dev/null 2>&1); then
        log_info "$(_ "dns.endpoint.success" "$ip" "$tls_hostname")"
        return
    fi

    output=$(tail -n 3 <<< "$output" | tr '\n' ' ')
    log_warn "$(_ "dns.endpoint.failed" "$ip" "$tls_hostname" "$output")"
    return 1
}

# @type:        Orchestrator
# @description: Validates every endpoint in a resolver profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 all endpoints validated
#               4 one or more endpoints unavailable
#               1 unsupported profile
dns::endpoint::check_profile() {
    local profile="$1"
    local record ip tls_hostname

    dns::profile::is_valid "$profile" || return 1
    while IFS= read -r -d '' record; do
        IFS=$'\t' read -r ip tls_hostname <<< "$record"
        dns::endpoint::check "$ip" "$tls_hostname" || return 4
    done < <(dns::profile::get_endpoints "$profile")
}

# @type:        Orchestrator
# @description: Checks every precondition for applying a DNS profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 preflight passed
#               4 preconfiguration required
#               1 unsupported internal profile
dns::preflight::check_apply() {
    local profile="$1"

    dns::profile::is_valid "$profile" || return 1
    dns::preflight::check_system || return $?
    dns::preflight::check_target "false" || return $?

    if ! dns::config::get_effective >/dev/null 2>&1; then
        log_warn "$(_ "dns.preflight.effective_unavailable")"
        return 4
    fi

    local domain_output
    if ! domain_output=$(resolvectl --no-pager domain 2>/dev/null); then
        log_warn "$(_ "dns.preflight.runtime_unavailable")"
        return 4
    fi

    local route_issue
    if IFS= read -r -d '' route_issue < <(dns::runtime::route_issues <<< "$domain_output"); then
        local _ link domain
        IFS=$'\t' read -r _ link domain <<< "$route_issue"
        log_warn "$(_ "dns.preflight.route_domain" "$link" "$domain")"
        return 4
    fi

    local conflict
    if IFS= read -r -d '' conflict < <(dns::config::late_conflicts); then
        log_warn "$(_ "dns.preflight.late_conflict" "$conflict")"
        return 4
    fi

    dns::endpoint::check_profile "$profile"
}

# @type:        Orchestrator
# @description: Checks every precondition for removing the BSSS DNS configuration
# @stdin:       None
# @stdout:      None
# @exit_code:   0 preflight passed
#               4 preconfiguration required
dns::preflight::check_remove() {
    dns::preflight::check_system || return $?
    dns::preflight::check_target "true"
}

# @type:        Validator
# @description: Checks whether the BSSS DNS file already matches a profile exactly
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 exact content match
#               1 target missing, foreign, or different
dns::config::matches_profile() {
    dns::config::is_owned "$BSSS_DNS_CONFIG_FILE" || return 1
    cmp --silent "$BSSS_DNS_CONFIG_FILE" <(dns::config::render "$1")
}

# @type:        Sink
# @description: Atomically installs a rendered BSSS DNS profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 configuration installed
#               1 write or ownership update failed
dns::config::install() {
    local profile="$1"
    local tmp

    if [[ ! -d "$DNS_RESOLVED_CONFIG_DIR" ]]; then
        mkdir -m 755 "$DNS_RESOLVED_CONFIG_DIR" || return 1
    fi
    tmp=$(mktemp "${DNS_RESOLVED_CONFIG_DIR}/.${UTIL_NAME}-dot-XXXXXX") || return 1

    if ! dns::config::render "$profile" > "$tmp" ||
        ! chown root:root "$tmp" ||
        ! chmod 644 "$tmp" ||
        ! mv -f "$tmp" "$BSSS_DNS_CONFIG_FILE"; then
        rm -f "$tmp"
        log_error "$(_ "dns.config.install_failed" "$BSSS_DNS_CONFIG_FILE")"
        return 1
    fi

    log_info "$(_ "dns.config.installed" "$BSSS_DNS_CONFIG_FILE")"
}

# @type:        Sink
# @description: Removes the BSSS-owned DNS target
# @stdin:       None
# @stdout:      None
# @exit_code:   0 target removed or absent
#               1 target is foreign or deletion failed
dns::config::remove() {
    if [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]]; then
        if ! dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
            log_error "$(_ "dns.config.foreign_target" "$BSSS_DNS_CONFIG_FILE")"
            return 1
        fi

        printf '%s\0' "$BSSS_DNS_CONFIG_FILE" | sys::file::delete
    fi
}

# @type:        Orchestrator
# @description: Restarts systemd-resolved
# @stdin:       None
# @stdout:      None
# @exit_code:   0 service restarted
#               1 restart failed
dns::service::restart() {
    log_info "$(_ "common.log_command" "systemctl restart $DNS_RESOLVED_SERVICE")"
    if ! systemctl restart "$DNS_RESOLVED_SERVICE"; then
        log_error "$(_ "dns.service.restart_failed" "$DNS_RESOLVED_SERVICE")"
        return 1
    fi
    log_info "$(_ "dns.service.restarted" "$DNS_RESOLVED_SERVICE")"
}

# @type:        Orchestrator
# @description: Flushes caches and performs a bounded DNS query through systemd-resolved
# @stdin:       None
# @stdout:      None
# @exit_code:   0 query completed
#               1 cache flush or query failed
dns::resolver::query() {
    local output

    log_info "$(_ "common.log_command" "resolvectl flush-caches")"
    resolvectl flush-caches || return 1
    log_info "$(_ "common.log_command" "timeout ${DNS_QUERY_TIMEOUT_SECONDS}s resolvectl query --cache=no $DNS_TEST_DOMAIN")"
    if output=$(timeout "${DNS_QUERY_TIMEOUT_SECONDS}s" resolvectl query --cache=no "$DNS_TEST_DOMAIN" 2>&1); then
        log_info "$(_ "dns.query.success" "$DNS_TEST_DOMAIN")"
        return
    fi

    output=$(tail -n 3 <<< "$output" | tr '\n' ' ')
    log_error "$(_ "dns.query.failed" "$DNS_TEST_DOMAIN" "$output")"
    return 1
}

# @type:        Orchestrator
# @description: Validates standard system DNS resolution after a mutation
# @stdin:       None
# @stdout:      None
# @exit_code:   0 resolver and query are operational
#               1 validation failed
dns::resolver::validate_standard() {
    systemctl is-active --quiet "$DNS_RESOLVED_SERVICE" || return 1
    dns::runtime::stub_is_listening || return 1
    dns::resolver::query
}

# @type:        Orchestrator
# @description: Validates and logs the complete supported protected DNS state
# @stdin:       None
# @stdout:      None
# @exit_code:   0 protection confirmed
#               1 validation failed
dns::resolver::validate_protected() {
    dns::resolver::validate_standard || return 1
    if ! dns::status::is_protected; then
        dns::log::status
        return 1
    fi
    dns::log::status
}

# @type:        Orchestrator
# @description: Saves exact BSSS target bytes for a standalone watchdog rollback
# @stdin:       None
# @stdout:      None
# @exit_code:   0 rollback state prepared
#               1 snapshot failed
dns::rollback::prepare() {
    [[ ! -e "$BSSS_DNS_ROLLBACK_FILE" && ! -L "$BSSS_DNS_ROLLBACK_FILE" ]]

    if dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
        cp -p "$BSSS_DNS_CONFIG_FILE" "$BSSS_DNS_ROLLBACK_FILE" || return 1
        log_info "$(_ "dns.rollback.snapshot_created" "$BSSS_DNS_ROLLBACK_FILE")"
    fi
}

# @type:        Sink
# @description: Deletes the transient DNS rollback snapshot after commit
# @stdin:       None
# @stdout:      None
# @exit_code:   0 snapshot removed or absent
#               1 deletion failed
dns::rollback::cleanup() {
    if [[ -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]]; then
        printf '%s\0' "$BSSS_DNS_ROLLBACK_FILE" | sys::file::delete
    fi
}

# @type:        Orchestrator
# @description: Restores the exact pre-transaction DNS state
# @stdin:       None
# @stdout:      None
# @exit_code:   0 state restored and resolver restarted
#               1 restoration or validation failed
dns::rollback::restore() {
    if [[ -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]]; then
        if ! dns::config::is_owned "$BSSS_DNS_ROLLBACK_FILE"; then
            log_error "$(_ "dns.rollback.foreign_snapshot" "$BSSS_DNS_ROLLBACK_FILE")"
            return 1
        fi
        if [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]] &&
            ! dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
            log_error "$(_ "dns.config.foreign_target" "$BSSS_DNS_CONFIG_FILE")"
            return 1
        fi
        mv -f "$BSSS_DNS_ROLLBACK_FILE" "$BSSS_DNS_CONFIG_FILE" || return 1
        log_info "$(_ "dns.rollback.snapshot_restored" "$BSSS_DNS_CONFIG_FILE")"
    else
        dns::config::remove || return 1
        log_info "$(_ "dns.rollback.new_config_removed")"
    fi

    dns::service::restart || return 1
    dns::resolver::validate_standard
}

# @type:        Orchestrator
# @description: Applies and validates a DNS profile without managing a watchdog
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 profile applied or already effective
#               1 mutation or validation failed
dns::orchestrator::apply() {
    local profile="$1"

    if dns::config::matches_profile "$profile"; then
        log_info "$(_ "dns.config.already_installed" "$BSSS_DNS_CONFIG_FILE")"
        dns::resolver::validate_protected
        return
    fi

    dns::config::install "$profile" || return 1
    dns::service::restart || return 1
    dns::resolver::validate_protected
}

# @type:        Orchestrator
# @description: Starts a standalone DNS watchdog transaction
# @stdin:       None
# @stdout:      None
# @exit_code:   0 watchdog ready
#               $? FIFO or watchdog startup failure
dns::transaction::start() {
    make_fifo_and_start_reader
    start_sync_rollback
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "dns" "" "$DNS_WATCHDOG_TIMEOUT_SECONDS")
    stop_sync_rollback
}

# @type:        Orchestrator
# @description: Commits a standalone DNS watchdog transaction
# @stdin:       None
# @stdout:      None
# @exit_code:   0 transaction committed
#               1 cleanup failed
dns::transaction::commit() {
    rollback::orchestrator::watchdog_stop
    WATCHDOG_PID=""
    dns::rollback::cleanup
    log_info "$(_ "common.success_changes_committed")"
}

# @type:        Orchestrator
# @description: Applies a selected DNS profile transactionally
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 profile applied or already effective
#               3 watchdog rollback completed
#               4 preconfiguration required
#               1 mutation or rollback failure
dns::transaction::apply() {
    local profile="$1"

    dns::preflight::check_apply "$profile" || return $?
    if dns::config::matches_profile "$profile"; then
        dns::orchestrator::apply "$profile"
        return
    fi

    dns::rollback::prepare
    dns::transaction::start
    if ! dns::orchestrator::apply "$profile"; then
        rollback::orchestrator::trigger_immediate
    fi
    dns::transaction::commit
}

# @type:        Orchestrator
# @description: Removes the BSSS DNS configuration transactionally
# @stdin:       None
# @stdout:      None
# @exit_code:   0 configuration removed and underlying DNS validated
#               3 watchdog rollback completed
#               4 preconfiguration required
#               1 mutation or rollback failure
dns::transaction::remove() {
    dns::preflight::check_remove || return $?
    dns::rollback::prepare
    dns::transaction::start
    if ! dns::config::remove ||
        ! dns::service::restart ||
        ! dns::resolver::validate_standard; then
        rollback::orchestrator::trigger_immediate
    fi
    dns::transaction::commit
    dns::log::status
}

# @type:        Orchestrator
# @description: Force-removes BSSS DNS state for full rollback
# @stdin:       None
# @stdout:      None
# @exit_code:   0 BSSS DNS state removed
#               1 foreign state, deletion, or restart failed
dns::orchestrator::dismantle() {
    local restart_required=false

    if [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]]; then
        dns::config::remove || return 1
        restart_required=true
    fi

    if [[ -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]]; then
        if ! dns::config::is_owned "$BSSS_DNS_ROLLBACK_FILE"; then
            log_error "$(_ "dns.rollback.foreign_snapshot" "$BSSS_DNS_ROLLBACK_FILE")"
            return 1
        fi
        dns::rollback::cleanup || return 1
    fi

    [[ "$restart_required" == "false" ]] || dns::service::restart
}

# @type:        Validator
# @description: Checks whether resolver bootstrap is released for the current Ubuntu version
# @stdin:       None
# @stdout:      None
# @exit_code:   0 bootstrap release supported
#               1 bootstrap release unsupported or unavailable
dns::prepare::os_is_supported() {
    local id version
    local supported_pattern="^(${DNS_BOOTSTRAP_SUPPORTED_UBUNTU_VERSIONS})$"

    IFS=$'\t' read -r id version < <(dns::os::get_release) || return 1
    [[ "$id" == "ubuntu" && "$version" =~ $supported_pattern ]]
}

# @type:        Validator
# @description: Checks that the test name cannot be answered from /etc/hosts
# @stdin:       None
# @stdout:      None
# @exit_code:   0 test name absent
#               1 test name found or hosts file unreadable
dns::prepare::test_name_is_external() {
    [[ -r "$HOSTS_FILE_PATH" ]] || return 1
    ! gawk -v name="$DNS_TEST_DOMAIN" '
        /^[[:space:]]*($|#)/ {
            next
        }
        {
            for (i = 2; i <= NF; i++) {
                value = tolower($i)
                sub(/\.$/, "", value)
                expected = tolower(name)
                sub(/\.$/, "", expected)
                if (value == expected) {
                    found = 1
                    exit
                }
            }
        }
        END { exit found ? 0 : 1 }
    ' "$HOSTS_FILE_PATH"
}

# @type:        Orchestrator
# @description: Validates direct libc DNS while systemd-resolved remains inactive
# @stdin:       None
# @stdout:      None
# @exit_code:   0 direct DNS query succeeded without activating resolved
#               1 query failed or resolved changed state
dns::direct::validate_query() {
    local output

    [[ "$(dns::service::get_property "$DNS_RESOLVED_SERVICE" "ActiveState")" == "inactive" ]] || return 1
    log_info "$(_ "common.log_command" "timeout ${DNS_QUERY_TIMEOUT_SECONDS}s getent ahosts $DNS_TEST_DOMAIN")"
    if ! output=$(timeout "${DNS_QUERY_TIMEOUT_SECONDS}s" getent ahosts "$DNS_TEST_DOMAIN" 2>&1); then
        output=$(tail -n 3 <<< "$output" | tr '\n' ' ')
        log_warn "$(_ "dns.prepare.direct_query_failed" "$DNS_TEST_DOMAIN" "$output")"
        return 1
    fi
    [[ -n "$output" ]] || return 1
    [[ "$(dns::service::get_property "$DNS_RESOLVED_SERVICE" "ActiveState")" == "inactive" ]]
}

# @type:        Orchestrator
# @description: Checks every condition for the narrow networkd-direct bootstrap
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 preparation can start
#               4 preconfiguration required
#               1 invalid internal profile
dns::prepare::preflight() {
    local profile="$1"
    local command listener conflict cmdline
    local -a commands=(
        systemctl systemd-analyze resolvectl readlink ss gawk openssl timeout
        mktemp mv cp cmp chown chmod mkdir rmdir rm ln flock sync sha256sum
        stat findmnt lsattr getent
    )

    dns::profile::is_valid "$profile" || return 1
    if ! dns::prepare::os_is_supported; then
        log_warn "$(_ "dns.prepare.unsupported_release" "$DNS_BOOTSTRAP_SUPPORTED_UBUNTU_VERSIONS")"
        return 4
    fi
    for command in "${commands[@]}"; do
        if ! command -v "$command" >/dev/null 2>&1; then
            log_warn "$(_ "dns.preflight.missing_command" "$command")"
            return 4
        fi
    done
    if ! dns::direct::is_baseline; then
        log_warn "$(_ "dns.prepare.baseline_required")"
        return 4
    fi
    if ! dns::direct::file_is_supported; then
        log_warn "$(_ "dns.prepare.resolv_unsupported" "$DNS_RESOLV_CONF_PATH")"
        return 4
    fi
    if dns::prepare::has_artifacts; then
        log_warn "$(_ "dns.prepare.recovery_required" "$DNS_PREPARE_DIR")"
        return 4
    fi
    if [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ||
        -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]]; then
        log_warn "$(_ "dns.prepare.existing_dns_state")"
        return 4
    fi
    if [[ -L "$DNS_RESOLVED_CONFIG_DIR" ||
        ( -e "$DNS_RESOLVED_CONFIG_DIR" && ! -d "$DNS_RESOLVED_CONFIG_DIR" ) ]]; then
        log_warn "$(_ "dns.preflight.config_dir" "$DNS_RESOLVED_CONFIG_DIR")"
        return 4
    fi
    if [[ -e "$BSSS_STATE_DIR" || -L "$BSSS_STATE_DIR" ]]; then
        dns::prepare::ensure_state_dir || {
            log_warn "$(_ "dns.prepare.state_dir_unsafe" "$BSSS_STATE_DIR")"
            return 4
        }
    fi
    if IFS= read -r -d '' listener < <(dns::runtime::local_resolvers); then
        log_warn "$(_ "dns.preflight.local_resolver" "$listener")"
        return 4
    fi
    cmdline=$(< /proc/cmdline) || return 4
    if gawk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^(nameserver|domain)=/) {
                    exit 0
                }
            }
            exit 1
        }
    ' <<< "$cmdline"; then
        log_warn "$(_ "dns.prepare.kernel_override")"
        return 4
    fi
    if ! dns::prepare::test_name_is_external; then
        log_warn "$(_ "dns.prepare.test_name_local" "$DNS_TEST_DOMAIN")"
        return 4
    fi
    if IFS= read -r -d '' conflict < <(dns::config::late_conflicts); then
        log_warn "$(_ "dns.preflight.late_conflict" "$conflict")"
        return 4
    fi
    if ! dns::direct::validate_query; then
        return 4
    fi
    dns::endpoint::check_profile "$profile"
}

# @type:        Orchestrator
# @description: Waits for exact systemd unit runtime state
# @params:      service Unit name (string) without a terminator
#               active_state Expected ActiveState (string) without a terminator
#               sub_state Expected SubState (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 expected state reached
#               1 timeout or property inspection failure
dns::service::wait_state() {
    local service="$1"
    local expected_active="$2"
    local expected_sub="$3"
    local attempts=$((DNS_SERVICE_POLL_SECONDS * 4))
    local active sub attempt

    for (( attempt = 0; attempt < attempts; attempt++ )); do
        active=$(dns::service::get_property "$service" "ActiveState") || return 1
        sub=$(dns::service::get_property "$service" "SubState") || return 1
        [[ "$active" == "$expected_active" && "$sub" == "$expected_sub" ]] && return
        sleep 0.25
    done
    return 1
}

# @type:        Orchestrator
# @description: Enables and starts systemd-resolved with bounded state polling
# @stdin:       None
# @stdout:      None
# @exit_code:   0 service enabled and running
#               1 enable, flush, start, or state validation failed
dns::service::enable_start() {
    log_info "$(_ "common.log_command" "systemctl enable $DNS_RESOLVED_SERVICE")"
    systemctl enable "$DNS_RESOLVED_SERVICE" || return 1
    [[ "$(dns::service::get_property "$DNS_RESOLVED_SERVICE" "UnitFileState")" == "enabled" ]] || return 1
    sync -f /etc/systemd/system || return 1

    log_info "$(_ "common.log_command" "systemctl start --no-block $DNS_RESOLVED_SERVICE")"
    systemctl start --no-block "$DNS_RESOLVED_SERVICE" || return 1
    dns::service::wait_state "$DNS_RESOLVED_SERVICE" "active" "running" || return 1
    log_info "$(_ "dns.prepare.service_started" "$DNS_RESOLVED_SERVICE")"
}

# @type:        Orchestrator
# @description: Stops and disables systemd-resolved with bounded state polling
# @stdin:       None
# @stdout:      None
# @exit_code:   0 service disabled and inactive
#               1 stop, disable, flush, or state validation failed
dns::service::stop_disable() {
    log_info "$(_ "common.log_command" "systemctl stop --no-block $DNS_RESOLVED_SERVICE")"
    systemctl stop --no-block "$DNS_RESOLVED_SERVICE" || return 1
    dns::service::wait_state "$DNS_RESOLVED_SERVICE" "inactive" "dead" || return 1

    log_info "$(_ "common.log_command" "systemctl disable $DNS_RESOLVED_SERVICE")"
    systemctl disable "$DNS_RESOLVED_SERVICE" || return 1
    [[ "$(dns::service::get_property "$DNS_RESOLVED_SERVICE" "UnitFileState")" == "disabled" ]] || return 1
    sync -f /etc/systemd/system
}

# @type:        Orchestrator
# @description: Performs an uncached non-synthetic DNS query through systemd-resolved
# @stdin:       None
# @stdout:      None
# @exit_code:   0 query succeeded
#               1 cache flush or query failed
dns::resolver::query_strict() {
    local output
    local command_text="timeout ${DNS_QUERY_TIMEOUT_SECONDS}s resolvectl query --protocol=dns --synthesize=no --cache=no $DNS_TEST_DOMAIN"

    log_info "$(_ "common.log_command" "resolvectl flush-caches")"
    resolvectl flush-caches || return 1
    log_info "$(_ "common.log_command" "$command_text")"
    if output=$(timeout "${DNS_QUERY_TIMEOUT_SECONDS}s" resolvectl query \
        --protocol=dns \
        --synthesize=no \
        --cache=no \
        "$DNS_TEST_DOMAIN" 2>&1); then
        log_info "$(_ "dns.query.success" "$DNS_TEST_DOMAIN")"
        return
    fi

    output=$(tail -n 3 <<< "$output" | tr '\n' ' ')
    log_error "$(_ "dns.query.failed" "$DNS_TEST_DOMAIN" "$output")"
    return 1
}

# @type:        Orchestrator
# @description: Proves exact strict runtime state before or after the stub switch
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 exact strict runtime confirmed
#               1 runtime evidence differs or is unavailable
dns::resolver::validate_strict_runtime() {
    local profile="$1"
    local expected_dns runtime_dns runtime_domains runtime_dot domain_output route_issue

    expected_dns=$(dns::profile::get_servers "$profile" | tr -d '\0') || return 1
    systemctl is-active --quiet "$DNS_RESOLVED_SERVICE" || return 1
    dns::runtime::stub_is_listening || return 1
    dns::config::matches_profile "$profile" || return 1

    IFS= read -r -d '' runtime_dns < <(dns::runtime::get_global "dns") || return 1
    IFS= read -r -d '' runtime_domains < <(dns::runtime::get_global "domain") || return 1
    IFS= read -r -d '' runtime_dot < <(dns::runtime::get_global "dnsovertls") || return 1
    [[ -n "$runtime_dns" && "$runtime_dns" == "$expected_dns" ]] || return 1
    [[ "$runtime_domains" == "~." && "$runtime_dot" == "yes" ]] || return 1

    domain_output=$(resolvectl --no-pager domain 2>/dev/null) || return 1
    if IFS= read -r -d '' route_issue < <(dns::runtime::route_issues <<< "$domain_output"); then
        return 1
    fi
    dns::resolver::query_strict
}

# @type:        Sink
# @description: Atomically switches /etc/resolv.conf to the standard resolved stub
# @stdin:       None
# @stdout:      None
# @exit_code:   0 durable symlink installed
#               1 foreign temp object, link, rename, flush, or validation failure
dns::prepare::switch_to_stub() {
    local resolv_dir="${DNS_RESOLV_CONF_PATH%/*}"

    [[ ! -e "$DNS_PREPARE_TEMP_LINK" && ! -L "$DNS_PREPARE_TEMP_LINK" ]] || return 1
    ln -s "$DNS_RESOLVED_STUB_PATH" "$DNS_PREPARE_TEMP_LINK" || return 1
    if [[ ! -L "$DNS_PREPARE_TEMP_LINK" ||
        "$(readlink "$DNS_PREPARE_TEMP_LINK")" != "$DNS_RESOLVED_STUB_PATH" ]]; then
        dns::prepare::remove_temp_link || true
        return 1
    fi
    mv -T "$DNS_PREPARE_TEMP_LINK" "$DNS_RESOLV_CONF_PATH" || return 1
    sync -f "$resolv_dir" || return 1
    [[ -L "$DNS_RESOLV_CONF_PATH" &&
        "$(readlink -f "$DNS_RESOLV_CONF_PATH")" == "$DNS_RESOLVED_STUB_PATH" ]]
}

# @type:        Sink
# @description: Atomically restores the direct resolver file from the recovery bundle
# @stdin:       None
# @stdout:      None
# @exit_code:   0 durable exact file restored
#               1 bundle, copy, rename, flush, or metadata validation failed
dns::prepare::restore_resolv_conf() {
    local bundle profile hash tmp expected actual
    local resolv_dir="${DNS_RESOLV_CONF_PATH%/*}"

    IFS= read -r -d '' bundle < <(dns::prepare::read_bundle "$DNS_PREPARE_DIR") || return 1
    IFS=$'\t' read -r profile hash <<< "$bundle"
    : "$profile"

    tmp=$(mktemp "${resolv_dir}/.resolv.conf.bsss_restore.XXXXXX") || return 1
    if ! cp -a -- "$DNS_PREPARE_BACKUP_FILE" "$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi
    actual=$(sha256sum "$tmp") || {
        rm -f -- "$tmp"
        return 1
    }
    [[ "${actual%% *}" == "$hash" ]] || {
        rm -f -- "$tmp"
        return 1
    }
    expected=$(stat -c $'%s\t%u\t%g\t%a' "$DNS_PREPARE_BACKUP_FILE") || {
        rm -f -- "$tmp"
        return 1
    }
    actual=$(stat -c $'%s\t%u\t%g\t%a' "$tmp") || {
        rm -f -- "$tmp"
        return 1
    }
    [[ "$actual" == "$expected" ]] || {
        rm -f -- "$tmp"
        return 1
    }

    mv -T "$tmp" "$DNS_RESOLV_CONF_PATH" || return 1
    sync -f "$resolv_dir" || return 1
    [[ -f "$DNS_RESOLV_CONF_PATH" && ! -L "$DNS_RESOLV_CONF_PATH" ]] || return 1
    actual=$(sha256sum "$DNS_RESOLV_CONF_PATH") || return 1
    [[ "${actual%% *}" == "$hash" ]] || return 1
    actual=$(stat -c $'%s\t%u\t%g\t%a' "$DNS_RESOLV_CONF_PATH") || return 1
    [[ "$actual" == "$expected" ]]
}

# @type:        Orchestrator
# @description: Restores the exact pre-preparation direct resolver baseline
# @stdin:       None
# @stdout:      None
# @exit_code:   0 baseline restored and bundle removed
#               1 safe restoration could not be proved
dns::prepare::rollback() {
    local bundle profile hash current_hash expected_metadata current_metadata

    IFS= read -r -d '' bundle < <(dns::prepare::read_bundle "$DNS_PREPARE_DIR") || return 1
    IFS=$'\t' read -r profile hash <<< "$bundle"
    : "$profile"

    if [[ -L "$DNS_RESOLV_CONF_PATH" ]] &&
        [[ "$(readlink -f "$DNS_RESOLV_CONF_PATH")" == "$DNS_RESOLVED_STUB_PATH" ]]; then
        dns::prepare::restore_resolv_conf || return 1
    elif [[ -f "$DNS_RESOLV_CONF_PATH" && ! -L "$DNS_RESOLV_CONF_PATH" ]]; then
        current_hash=$(sha256sum "$DNS_RESOLV_CONF_PATH") || return 1
        [[ "${current_hash%% *}" == "$hash" ]] || return 1
        expected_metadata=$(stat -c $'%s\t%u\t%g\t%a' "$DNS_PREPARE_BACKUP_FILE") || return 1
        current_metadata=$(stat -c $'%s\t%u\t%g\t%a' "$DNS_RESOLV_CONF_PATH") || return 1
        [[ "$current_metadata" == "$expected_metadata" ]] || return 1
    else
        return 1
    fi

    dns::prepare::remove_temp_link || return 1
    dns::service::stop_disable || return 1
    dns::config::remove || return 1
    if [[ -d "$DNS_RESOLVED_CONFIG_DIR" ]]; then
        sync -f "$DNS_RESOLVED_CONFIG_DIR" || return 1
    fi
    sync -f /etc/systemd/system || return 1
    dns::direct::validate_query || return 1
    dns::prepare::cleanup_bundle || return 1
    log_info "$(_ "dns.prepare.rollback_complete")"
}

# @type:        Orchestrator
# @description: Handles INT or TERM during resolver preparation
# @stdin:       None
# @stdout:      None
# @exit_code:   130 interrupted after successful rollback
#               1 rollback failed
dns::prepare::on_signal() {
    trap - INT TERM
    if dns::prepare::rollback; then
        dns::prepare::unlock
        exit 130
    fi
    dns::prepare::unlock
    exit 1
}

# @type:        Orchestrator
# @description: Applies strict DoT and standardizes the exact networkd-direct baseline
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 resolver prepared
#               3 changes failed and were rolled back
#               4 preconfiguration required
#               1 critical mutation or rollback failure
dns::prepare::run() {
    local profile="$1"
    local fingerprint current_fingerprint
    local rc

    dns::prepare::lock || return $?
    dns::prepare::preflight "$profile" || {
        rc=$?
        dns::prepare::unlock
        return "$rc"
    }
    IFS= read -r -d '' fingerprint < <(dns::direct::fingerprint) || {
        dns::prepare::unlock
        return 1
    }
    if ! dns::prepare::create_bundle "$profile"; then
        if [[ -d "$DNS_PREPARE_STAGING_DIR" ]] &&
            dns::prepare::partial_is_owned "$DNS_PREPARE_STAGING_DIR"; then
            dns::prepare::remove_partial "$DNS_PREPARE_STAGING_DIR" || true
        fi
        dns::prepare::unlock
        return 1
    fi

    trap dns::prepare::on_signal INT TERM
    if ! dns::config::install "$profile" ||
        ! sync -f "$DNS_RESOLVED_CONFIG_DIR" ||
        ! dns::service::enable_start ||
        ! dns::resolver::validate_strict_runtime "$profile"; then
        trap - INT TERM
        if dns::prepare::rollback; then
            trap common::int::actions INT
            trap - TERM
            dns::prepare::unlock
            return 3
        fi
        trap common::int::actions INT
        trap - TERM
        dns::prepare::unlock
        return 1
    fi

    IFS= read -r -d '' current_fingerprint < <(dns::direct::fingerprint) || current_fingerprint=""
    if [[ "$current_fingerprint" != "$fingerprint" ]] ||
        ! dns::prepare::switch_to_stub ||
        ! timeout "${DNS_QUERY_TIMEOUT_SECONDS}s" getent ahosts "$DNS_TEST_DOMAIN" >/dev/null ||
        ! dns::resolver::validate_strict_runtime "$profile" ||
        ! dns::status::is_protected; then
        trap - INT TERM
        if dns::prepare::rollback; then
            trap common::int::actions INT
            trap - TERM
            dns::prepare::unlock
            return 3
        fi
        trap common::int::actions INT
        trap - TERM
        dns::prepare::unlock
        return 1
    fi

    trap common::int::actions INT
    trap - TERM
    dns::prepare::cleanup_bundle || {
        dns::prepare::unlock
        return 1
    }
    dns::prepare::unlock
    log_success "$(_ "dns.prepare.success")"
    dns::log::status
}

# @type:        Orchestrator
# @description: Recovers an interrupted resolver preparation
# @stdin:       None
# @stdout:      None
# @exit_code:   0 interrupted state finalized or restored
#               4 foreign or inconsistent state requires manual inspection
#               1 recovery operation failed
dns::prepare::recover() {
    local bundle profile hash

    dns::prepare::lock || return $?
    if [[ -e "$DNS_PREPARE_STAGING_DIR" || -L "$DNS_PREPARE_STAGING_DIR" ]]; then
        if [[ -e "$DNS_PREPARE_DIR" || -L "$DNS_PREPARE_DIR" ||
            -e "$DNS_PREPARE_CLEANUP_DIR" || -L "$DNS_PREPARE_CLEANUP_DIR" ]] ||
            ! dns::prepare::partial_is_owned "$DNS_PREPARE_STAGING_DIR" ||
            ! dns::direct::is_baseline ||
            [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]]; then
            dns::prepare::unlock
            return 4
        fi
        dns::prepare::remove_temp_link || {
            dns::prepare::unlock
            return 4
        }
        dns::prepare::remove_partial "$DNS_PREPARE_STAGING_DIR" || {
            dns::prepare::unlock
            return 1
        }
        dns::prepare::unlock
        log_info "$(_ "dns.prepare.recovery_complete")"
        return
    fi

    if [[ -e "$DNS_PREPARE_CLEANUP_DIR" || -L "$DNS_PREPARE_CLEANUP_DIR" ]]; then
        if [[ -e "$DNS_PREPARE_DIR" || -L "$DNS_PREPARE_DIR" ]] ||
            ! dns::prepare::partial_is_owned "$DNS_PREPARE_CLEANUP_DIR" ||
            ! dns::status::is_protected; then
            dns::prepare::unlock
            return 4
        fi
        dns::prepare::remove_temp_link || {
            dns::prepare::unlock
            return 4
        }
        dns::prepare::remove_partial "$DNS_PREPARE_CLEANUP_DIR" || {
            dns::prepare::unlock
            return 1
        }
        dns::prepare::unlock
        log_info "$(_ "dns.prepare.recovery_complete")"
        return
    fi

    if [[ ! -e "$DNS_PREPARE_DIR" && ! -L "$DNS_PREPARE_DIR" &&
        ( -e "$DNS_PREPARE_TEMP_LINK" || -L "$DNS_PREPARE_TEMP_LINK" ) ]]; then
        if ! dns::direct::is_baseline ||
            [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]]; then
            dns::prepare::unlock
            return 4
        fi
        dns::prepare::remove_temp_link || {
            dns::prepare::unlock
            return 4
        }
        dns::prepare::unlock
        log_info "$(_ "dns.prepare.recovery_complete")"
        return
    fi

    IFS= read -r -d '' bundle < <(dns::prepare::read_bundle "$DNS_PREPARE_DIR") || {
        dns::prepare::unlock
        return 4
    }
    IFS=$'\t' read -r profile hash <<< "$bundle"
    : "$hash"

    if [[ -L "$DNS_RESOLV_CONF_PATH" ]] &&
        [[ "$(readlink -f "$DNS_RESOLV_CONF_PATH")" == "$DNS_RESOLVED_STUB_PATH" ]] &&
        dns::resolver::validate_strict_runtime "$profile" &&
        timeout "${DNS_QUERY_TIMEOUT_SECONDS}s" getent ahosts "$DNS_TEST_DOMAIN" >/dev/null &&
        dns::status::is_protected; then
        dns::prepare::cleanup_bundle || {
            dns::prepare::unlock
            return 1
        }
    else
        dns::prepare::rollback || {
            dns::prepare::unlock
            return 1
        }
    fi

    dns::prepare::unlock
    log_info "$(_ "dns.prepare.recovery_complete")"
}

# @type:        Orchestrator
# @description: Refuses full rollback before its watchdog when preparation may be active
# @stdin:       None
# @stdout:      None
# @exit_code:   0 lock held and no preparation artifacts exist
#               1 full rollback must not start
dns::prepare::guard_full_rollback() {
    if ! dns::prepare::lock; then
        log_error "$(_ "dns.prepare.full_rollback_blocked")"
        return 1
    fi
    if dns::prepare::has_artifacts; then
        log_error "$(_ "dns.prepare.full_rollback_blocked")"
        dns::prepare::unlock
        return 1
    fi
}
