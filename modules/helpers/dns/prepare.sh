# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Sink
# @description: Atomically switches resolv.conf to the standard resolved stub
# @stdin:       None
# @stdout:      None
# @exit_code:   0 durable symlink installed
#               1 foreign temp object, link, rename, flush, or validation failure
dns::prepare::switch_to_stub() {
    local resolv_dir="${DNS_RESOLV_CONF_PATH%/*}"

    [[ ! -e "$DNS_PREPARE_TEMP_LINK" && ! -L "$DNS_PREPARE_TEMP_LINK" ]] ||
        return 1
    ln -s "$DNS_RESOLVED_STUB_PATH" "$DNS_PREPARE_TEMP_LINK" || return 1
    if [[ ! -L "$DNS_PREPARE_TEMP_LINK" ||
        "$(readlink "$DNS_PREPARE_TEMP_LINK")" != "$DNS_RESOLVED_STUB_PATH" ]]; then
        dns::recovery::remove_temp_link || true
        return 1
    fi
    mv -T "$DNS_PREPARE_TEMP_LINK" "$DNS_RESOLV_CONF_PATH" || return 1
    sync -f "$resolv_dir" || return 1
    [[ -L "$DNS_RESOLV_CONF_PATH" &&
        "$(readlink -f "$DNS_RESOLV_CONF_PATH")" == "$DNS_RESOLVED_STUB_PATH" ]]
}

# @type:        Sink
# @description: Removes the BSSS configuration created during direct preparation
# @stdin:       None
# @stdout:      None
# @exit_code:   0 target absent and removal flushed
#               1 foreign target, deletion, or flush failure
dns::prepare::remove_config() {
    if [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]]; then
        dns::config::is_owned "$BSSS_DNS_CONFIG_FILE" || return 1
        rm -- "$BSSS_DNS_CONFIG_FILE" || return 1
    fi
    if [[ -d "$DNS_RESOLVED_CONFIG_DIR" ]]; then
        sync -f "$DNS_RESOLVED_CONFIG_DIR" || return 1
    fi
}

# @type:        Validator
# @description: Confirms that current direct resolv.conf still matches the recovery bundle
# @stdin:       None
# @stdout:      None
# @exit_code:   0 exact direct file remains
#               1 bundle or resolver bytes and metadata differ
dns::prepare::direct_matches_bundle() {
    local bundle hash expected actual

    IFS= read -r -d '' bundle < <(
        dns::recovery::read_bundle "$DNS_PREPARE_DIR"
    ) || return 1
    [[ "$bundle" == *$'\t'* && "${bundle#*$'\t'}" != *$'\t'* ]] || return 1
    hash="${bundle#*$'\t'}"

    [[ -f "$DNS_RESOLV_CONF_PATH" && ! -L "$DNS_RESOLV_CONF_PATH" ]] || return 1
    actual=$(sha256sum "$DNS_RESOLV_CONF_PATH") || return 1
    [[ "${actual%% *}" == "$hash" ]] || return 1
    expected=$(stat -c $'%s\t%u\t%g\t%a' "$DNS_PREPARE_BACKUP_FILE") || return 1
    actual=$(stat -c $'%s\t%u\t%g\t%a' "$DNS_RESOLV_CONF_PATH") || return 1
    [[ "$actual" == "$expected" ]]
}

# @type:        Orchestrator
# @description: Restores the exact pre-preparation networkd-direct baseline
# @stdin:       None
# @stdout:      None
# @exit_code:   0 baseline restored and bundle removed
#               1 safe restoration could not be proved
dns::prepare::rollback() {
    if [[ -L "$DNS_RESOLV_CONF_PATH" ]] &&
        [[ "$(readlink -f "$DNS_RESOLV_CONF_PATH")" == "$DNS_RESOLVED_STUB_PATH" ]]; then
        dns::recovery::restore_resolv_conf || return 1
    else
        dns::prepare::direct_matches_bundle || return 1
    fi

    dns::recovery::remove_temp_link || return 1
    dns::service::stop_disable || return 1
    dns::prepare::remove_config || return 1
    dns::runtime::query_libc "$DNS_TEST_DOMAIN" || return 1
    dns::state::direct_baseline || return 1
    dns::recovery::cleanup_bundle
}

# @type:        Orchestrator
# @description: Aborts an active resolver preparation after INT or TERM
# @stdin:       None
# @stdout:      None
# @exit_code:   130 interrupted with safe rollback or before mutation
#               1 rollback failed
dns::prepare::on_signal() {
    trap - INT TERM

    if [[ -n "$DNS_PREPARE_LOCK_FD" ]] && dns::recovery::has_artifacts; then
        if dns::prepare::rollback; then
            dns::recovery::unlock
            exit 130
        fi
        dns::recovery::unlock
        exit 1
    fi
    dns::recovery::unlock
    exit 130
}

# @type:        Orchestrator
# @description: Applies strict DoT and standardizes an exact networkd-direct baseline
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 resolver prepared
#               1 technical mutation or rollback failure
#               3 changes failed and were rolled back
#               4 preconfiguration required or lock busy
dns::prepare::apply() {
    local profile="$1"
    local fingerprint="" current_fingerprint="" status

    dns::recovery::lock || return
    if dns::check::apply "networkd-direct" "$profile"; then
        :
    else
        status=$?
        dns::recovery::unlock
        return "$status"
    fi
    IFS= read -r -d '' fingerprint < <(dns::recovery::fingerprint) || {
        dns::recovery::unlock
        return 1
    }
    if ! dns::recovery::create_bundle "$profile"; then
        if [[ -d "$DNS_PREPARE_STAGING_DIR" ]] &&
            dns::recovery::partial_is_owned "$DNS_PREPARE_STAGING_DIR"; then
            dns::recovery::remove_partial "$DNS_PREPARE_STAGING_DIR" || true
        fi
        dns::recovery::unlock
        return 1
    fi

    if dns::resolved::install "$profile" &&
        sync -f "$DNS_RESOLVED_CONFIG_DIR" &&
        dns::service::enable_start &&
        dns::validate::strict_runtime "$profile"; then
        IFS= read -r -d '' current_fingerprint < <(dns::recovery::fingerprint) ||
            current_fingerprint=""
    fi
    if [[ -z "$current_fingerprint" || "$current_fingerprint" != "$fingerprint" ]] ||
        ! dns::prepare::switch_to_stub ||
        ! dns::validate::protected "$profile"; then
        if dns::prepare::rollback; then
            dns::recovery::unlock
            return 3
        fi
        dns::recovery::unlock
        return 1
    fi

    if ! dns::recovery::cleanup_bundle; then
        dns::recovery::unlock
        return 1
    fi
    dns::recovery::unlock
}

# @type:        Source
# @description: Returns the profile installed by the BSSS target
# @stdin:       None
# @stdout:      profile\0
# @exit_code:   0 one exact profile found
#               1 target missing or does not match a known profile
dns::prepare::installed_profile() {
    local profile

    for profile in "$DNS_PROFILE_GOOGLE_CLOUDFLARE" "$DNS_PROFILE_YANDEX_GOOGLE"; do
        if dns::config::matches_profile "$profile"; then
            printf '%s\0' "$profile"
            return
        fi
    done
    return 1
}

# @type:        Orchestrator
# @description: Recovers or finalizes an interrupted direct resolver preparation
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on an inconsistent state
# @exit_code:   0 interrupted state finalized or restored
#               1 recovery operation failed
#               4 foreign or inconsistent state requires manual inspection
dns::prepare::recover() {
    local bundle profile status

    dns::recovery::lock || return

    if [[ -e "$DNS_PREPARE_STAGING_DIR" || -L "$DNS_PREPARE_STAGING_DIR" ]]; then
        if [[ -e "$DNS_PREPARE_DIR" || -L "$DNS_PREPARE_DIR" ||
            -e "$DNS_PREPARE_CLEANUP_DIR" || -L "$DNS_PREPARE_CLEANUP_DIR" ]] ||
            ! dns::recovery::partial_is_owned "$DNS_PREPARE_STAGING_DIR" ||
            ! dns::state::direct_baseline ||
            [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]] ||
            ! dns::recovery::remove_temp_link; then
            dns::recovery::unlock
            dns::check::block "recovery_inconsistent"
            return
        fi
        dns::recovery::remove_partial "$DNS_PREPARE_STAGING_DIR" || {
            dns::recovery::unlock
            return 1
        }
        dns::recovery::unlock
        return
    fi

    if [[ -e "$DNS_PREPARE_CLEANUP_DIR" || -L "$DNS_PREPARE_CLEANUP_DIR" ]]; then
        if [[ -e "$DNS_PREPARE_DIR" || -L "$DNS_PREPARE_DIR" ]] ||
            ! dns::recovery::partial_is_owned "$DNS_PREPARE_CLEANUP_DIR"; then
            dns::recovery::unlock
            dns::check::block "recovery_inconsistent"
            return
        fi
        IFS= read -r -d '' profile < <(dns::prepare::installed_profile) || {
            dns::recovery::unlock
            dns::check::block "recovery_inconsistent"
            return
        }
        if ! dns::validate::protected "$profile" >/dev/null ||
            ! dns::recovery::remove_temp_link; then
            dns::recovery::unlock
            dns::check::block "recovery_inconsistent"
            return
        fi
        dns::recovery::remove_partial "$DNS_PREPARE_CLEANUP_DIR" || {
            dns::recovery::unlock
            return 1
        }
        sync -f "$BSSS_STATE_DIR" || {
            dns::recovery::unlock
            return 1
        }
        dns::recovery::unlock
        return
    fi

    if [[ ! -e "$DNS_PREPARE_DIR" && ! -L "$DNS_PREPARE_DIR" &&
        ( -e "$DNS_PREPARE_TEMP_LINK" || -L "$DNS_PREPARE_TEMP_LINK" ) ]]; then
        if ! dns::state::direct_baseline ||
            [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]] ||
            ! dns::recovery::remove_temp_link; then
            dns::recovery::unlock
            dns::check::block "recovery_inconsistent"
            return
        fi
        dns::recovery::unlock
        return
    fi

    IFS= read -r -d '' bundle < <(
        dns::recovery::read_bundle "$DNS_PREPARE_DIR"
    ) || {
        dns::recovery::unlock
        dns::check::block "recovery_inconsistent"
        return
    }
    [[ "$bundle" == *$'\t'* && "${bundle#*$'\t'}" != *$'\t'* ]] || {
        dns::recovery::unlock
        return 1
    }
    profile="${bundle%%$'\t'*}"

    if dns::validate::protected "$profile" >/dev/null; then
        dns::recovery::cleanup_bundle || status=1
    else
        dns::prepare::rollback || status=1
    fi
    status="${status:-0}"
    dns::recovery::unlock
    return "$status"
}

# @type:        Orchestrator
# @description: Holds the DNS operation lock and refuses unsafe full rollback
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 lock held and no interrupted DNS state exists
#               1 artifact inspection failure
#               4 lock busy or interrupted DNS state requires standalone recovery
dns::prepare::guard_full_rollback() {
    local status

    if dns::recovery::lock; then
        :
    else
        status=$?
        if (( status == 4 )); then
            dns::check::block "operation_locked"
            return
        fi
        return "$status"
    fi
    if dns::mode::has_artifacts; then
        dns::recovery::unlock
        dns::check::block "recovery_required"
        return
    fi
}
