# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Sink
# @description: Saves the current BSSS DNS target for a synchronous transaction
# @stdin:       None
# @stdout:      None
# @exit_code:   0 snapshot prepared
#               1 stale, foreign, or copy failure
dns::resolved::snapshot() {
    [[ ! -e "$BSSS_DNS_ROLLBACK_FILE" && ! -L "$BSSS_DNS_ROLLBACK_FILE" ]] || return 1
    if [[ ! -e "$BSSS_DNS_CONFIG_FILE" && ! -L "$BSSS_DNS_CONFIG_FILE" ]]; then
        return
    fi
    dns::config::is_owned "$BSSS_DNS_CONFIG_FILE" || return 1
    cp --preserve=mode,ownership,timestamps \
        "$BSSS_DNS_CONFIG_FILE" \
        "$BSSS_DNS_ROLLBACK_FILE" ||
        return 1
}

# @type:        Sink
# @description: Atomically installs one rendered BSSS resolved configuration
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 configuration installed
#               1 render or filesystem failure
dns::resolved::install() {
    local profile="$1"
    local temporary_file

    dns::profile::is_valid "$profile" || return 1
    if [[ ! -e "$DNS_RESOLVED_CONFIG_DIR" && ! -L "$DNS_RESOLVED_CONFIG_DIR" ]]; then
        mkdir -m 755 "$DNS_RESOLVED_CONFIG_DIR" || return 1
    fi
    [[ -d "$DNS_RESOLVED_CONFIG_DIR" && ! -L "$DNS_RESOLVED_CONFIG_DIR" ]] || return 1

    temporary_file=$(mktemp "${DNS_RESOLVED_CONFIG_DIR}/.${BSSS_DNS_CONFIG_FILE_NAME}.XXXXXX") ||
        return 1
    if ! dns::config::render "$profile" > "$temporary_file"; then
        rm -f "$temporary_file" || true
        return 1
    fi
    if ! chown root:root "$temporary_file" ||
        ! chmod 0644 "$temporary_file" ||
        ! mv -fT "$temporary_file" "$BSSS_DNS_CONFIG_FILE"; then
        rm -f "$temporary_file" || true
        return 1
    fi
}

# @type:        Sink
# @description: Restarts systemd-resolved and confirms its active state
# @stdin:       None
# @stdout:      None
# @exit_code:   0 service restarted and active
#               $? systemctl failure
dns::resolved::restart() {
    dns::service::restart
}

# @type:        Sink
# @description: Flushes the systemd-resolved cache
# @stdin:       None
# @stdout:      None
# @exit_code:   0 cache flushed
#               $? resolvectl failure
dns::resolved::flush_cache() {
    resolvectl flush-caches
}

# @type:        Validator
# @description: Confirms usable standard resolver service after rollback
# @stdin:       None
# @stdout:      None
# @exit_code:   0 standard resolution works
#               1 restored state is unusable
dns::resolved::validate_standard() {
    dns::check::mode "resolved-stub" >/dev/null || return 1
    dns::runtime::stub_is_listening || return 1
    dns::runtime::query_libc "$DNS_TEST_DOMAIN"
}

# @type:        Sink
# @description: Restores the exact previous BSSS target or removes a new target
# @stdin:       None
# @stdout:      None
# @exit_code:   0 previous state restored and usable
#               1 restore, restart, or validation failure
dns::resolved::restore() {
    if [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]] &&
        ! dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
        return 1
    fi

    if [[ -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]]; then
        [[ -f "$BSSS_DNS_ROLLBACK_FILE" && ! -L "$BSSS_DNS_ROLLBACK_FILE" ]] || return 1
        mv -fT "$BSSS_DNS_ROLLBACK_FILE" "$BSSS_DNS_CONFIG_FILE" || return 1
    elif [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]]; then
        rm -- "$BSSS_DNS_CONFIG_FILE" || return 1
    fi

    dns::resolved::restart || return 1
    dns::resolved::flush_cache || return 1
    dns::resolved::validate_standard
}

# @type:        Sink
# @description: Removes a successful transaction snapshot
# @stdin:       None
# @stdout:      None
# @exit_code:   0 snapshot absent
#               1 snapshot removal failed
dns::resolved::cleanup() {
    if [[ -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]]; then
        rm -- "$BSSS_DNS_ROLLBACK_FILE" || return 1
    fi
}

# @type:        Orchestrator
# @description: Restores the previous resolver state after a transaction failure
# @stdin:       None
# @stdout:      None
# @exit_code:   3 rollback completed
#               1 rollback failed
dns::resolved::rollback() {
    dns::resolved::restore || return 1
    return 3
}

# @type:        Orchestrator
# @description: Applies and validates one resolved-stub profile transactionally
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 profile applied and validated
#               1 technical error or failed rollback
#               3 validation or mutation failed and rollback completed
#               4 preflight or unchanged-state validation blocker
dns::resolved::apply() {
    local profile="$1"

    dns::check::apply "resolved-stub" "$profile" || return
    if dns::config::matches_profile "$profile"; then
        dns::validate::protected "$profile"
        return
    fi

    dns::resolved::snapshot || return 1
    dns::resolved::install "$profile" ||
        dns::resolved::rollback ||
        return
    dns::resolved::restart ||
        dns::resolved::rollback ||
        return
    dns::resolved::flush_cache ||
        dns::resolved::rollback ||
        return
    dns::validate::protected "$profile" ||
        dns::resolved::rollback ||
        return
    dns::resolved::cleanup ||
        dns::resolved::rollback ||
        return
}
