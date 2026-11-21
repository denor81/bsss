# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Source
# @description: Returns the localized resolver profile name
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      profile_name without a terminator
# @exit_code:   0 profile found
#               1 unsupported profile
dns::presentation::profile_name() {
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
dns::presentation::select_profile() {
    log_info "$(_ "dns.auto.profile_question")"
    log_info_simple_tab "1. $(_ "dns.menu.google_cloudflare")"
    log_info_simple_tab "2. $(_ "dns.menu.yandex_google")"

    local choice
    choice=$(io::ask_value "$(_ "common.ask_select_action")" "1" "^[1-2]$" "1-2" | tr -d '\0') ||
        return
    case "$choice" in
        1) printf '%s\0' "$DNS_PROFILE_GOOGLE_CLOUDFLARE" ;;
        2) printf '%s\0' "$DNS_PROFILE_YANDEX_GOOGLE" ;;
    esac
}

# @type:        Source
# @description: Formats an effective setting value for user-facing output
# @params:      value Raw setting value (string) without a terminator
# @stdin:       None
# @stdout:      display_value\n
# @exit_code:   0 value formatted
dns::presentation::display_value() {
    if [[ "$1" == "__unset__" ]]; then
        printf '%s\n' "$(_ "dns.value.unset")"
    else
        printf '%s\n' "$1"
    fi
}

# @type:        Sink
# @description: Renders diagnostic issue records as tabbed messages
# @stdin:       issue_code<TAB>argument...\0 (0..N)
# @stdout:      None
# @exit_code:   0 issues rendered
dns::presentation::issues() {
    local record="" code args arg1 arg2

    while IFS= read -r -d '' record; do
        [[ "$record" == *$'\t'* ]] || return 1
        code="${record%%$'\t'*}"
        args="${record#*$'\t'}"
        arg1="${args%%$'\t'*}"
        if [[ "$args" == *$'\t'* ]]; then
            arg2="${args#*$'\t'}"
        else
            arg2=""
        fi
        case "$code" in
            profile_unknown|fallback_dns|domains|dot_mode|dnssec|llmnr|multicast_dns|runtime_dns|runtime_domains|runtime_dot)
                arg1=$(dns::presentation::display_value "$arg1")
                ;;
        esac
        case "$code" in
            missing_command)       log_info_simple_tab "$(_ "dns.issue.missing_command" "$arg1")" ;;
            unsupported_os)        log_info_simple_tab "$(_ "dns.issue.unsupported_os" "$arg1")" ;;
            resolved_inactive)     log_info_simple_tab "$(_ "dns.issue.resolved_inactive")" ;;
            resolv_conf)           log_info_simple_tab "$(_ "dns.issue.resolv_conf" "$arg1")" ;;
            stub_inactive)         log_info_simple_tab "$(_ "dns.issue.stub_inactive")" ;;
            local_resolver)        log_info_simple_tab "$(_ "dns.issue.local_resolver" "$arg1")" ;;
            bsss_config)           log_info_simple_tab "$(_ "dns.config.bsss_absent" "$arg1")" ;;
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
        record=""
    done
    [[ -z "$record" ]]
}

# @type:        Sink
# @description: Logs effective settings from the BSSS-owned DNS configuration
# @stdin:       None
# @stdout:      None
# @exit_code:   0 configuration logged or absent
#               1 parser failure
dns::presentation::bsss_config() {
    local record="" name value

    if ! dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
        log_info "$(_ "dns.config.bsss_absent" "$BSSS_DNS_CONFIG_FILE")"
        return
    fi
    log_info "$(_ "dns.config.bsss_found")"
    while IFS= read -r -d '' record; do
        [[ "$record" == *$'\t'* ]] || return 1
        name="${record%%$'\t'*}"
        value="${record#*$'\t'}"
        [[ "$value" == "__unset__" ]] ||
            log_info_simple_tab "$(_ "no_translate" "${BSSS_DNS_CONFIG_FILE}:${name}=${value}")"
        record=""
    done < <(dns::config::parse_effective < "$BSSS_DNS_CONFIG_FILE")
    [[ -z "$record" ]]
}

# @type:        Sink
# @description: Logs protected DNS status or every detected issue
# @stdin:       None
# @stdout:      None
# @exit_code:   0 status logged
#               1 inspection or rendering failure
dns::presentation::status() {
    local profile

    if dns::diagnostics::is_protected; then
        IFS= read -r -d '' profile < <(dns::config::get_profile) || return 1
        case "$profile" in
            "$DNS_PROFILE_GOOGLE_CLOUDFLARE") log_info "$(_ "dns.status.protected_google_cloudflare")" ;;
            "$DNS_PROFILE_YANDEX_GOOGLE") log_info "$(_ "dns.status.protected_yandex_google")" ;;
            *) return 1 ;;
        esac
        dns::presentation::bsss_config
        return
    fi

    log_warn "$(_ "dns.status.unconfirmed")"
    dns::diagnostics::issues | dns::presentation::issues
}
