# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Filter
# @description: Emits every mismatch found in effective resolved settings
# @stdin:       setting<TAB>value\0 (7 records)
# @stdout:      issue_code<TAB>arguments...\0 (0..N)
# @exit_code:   0 settings inspected
#               1 malformed or incomplete input
dns::diagnostics::effective_issues() {
    local record="" key value
    local -A settings=()
    local -a keys=(DNS FallbackDNS Domains DNSOverTLS DNSSEC LLMNR MulticastDNS)

    while IFS= read -r -d '' record; do
        [[ "$record" == *$'\t'* ]] || return 1
        key="${record%%$'\t'*}"
        value="${record#*$'\t'}"
        [[ -n "$key" && "$key" != *[$'\t\n']* && "$value" != *[$'\t\n']* ]] || return 1
        case "$key" in
            DNS|FallbackDNS|Domains|DNSOverTLS|DNSSEC|LLMNR|MulticastDNS) ;;
            *) return 1 ;;
        esac
        [[ ! -v "settings[$key]" ]] || return 1
        settings["$key"]="$value"
        record=""
    done
    [[ -z "$record" ]] || return 1
    for key in "${keys[@]}"; do
        [[ -v "settings[$key]" ]] || return 1
    done

    case "${settings[DNS]}" in
        "$DNS_SERVERS_GOOGLE_CLOUDFLARE"|"$DNS_SERVERS_YANDEX_GOOGLE") ;;
        *) dns::check::emit "profile_unknown" "${settings[DNS]}" || return 1 ;;
    esac
    [[ "${settings[FallbackDNS]}" == "" ]] ||
        dns::check::emit "fallback_dns" "${settings[FallbackDNS]}" ||
        return 1
    [[ "${settings[Domains]}" == "~." ]] ||
        dns::check::emit "domains" "${settings[Domains]}" ||
        return 1
    [[ "${settings[DNSOverTLS]}" == "yes" ]] ||
        dns::check::emit "dot_mode" "${settings[DNSOverTLS]}" ||
        return 1
    [[ "${settings[DNSSEC]}" == "no" ]] ||
        dns::check::emit "dnssec" "${settings[DNSSEC]}" ||
        return 1
    [[ "${settings[LLMNR]}" == "no" ]] ||
        dns::check::emit "llmnr" "${settings[LLMNR]}" ||
        return 1
    [[ "${settings[MulticastDNS]}" == "no" ]] ||
        dns::check::emit "multicast_dns" "${settings[MulticastDNS]}"
}

# @type:        Source
# @description: Emits all observable DNS protection issues without network mutation
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 (0..N)
# @exit_code:   0 diagnostics completed
#               1 malformed issue or unrecoverable parser failure
dns::diagnostics::issues() {
    local command missing=0
    local -a commands=(systemctl systemd-analyze resolvectl readlink ss gawk)

    for command in "${commands[@]}"; do
        if ! command -v "$command" >/dev/null 2>&1; then
            dns::check::emit "missing_command" "$command" || return 1
            missing=1
        fi
    done
    (( missing == 0 )) || return

    local release_record id version allow_empty=0
    if IFS= read -r -d '' release_record < <(dns::check::release); then
        id="${release_record%%$'\t'*}"
        version="${release_record#*$'\t'}"
        if [[ "$id" != "ubuntu" || ! "$version" =~ ^(${DNS_SUPPORTED_UBUNTU_VERSIONS})$ ]]; then
            dns::check::emit "unsupported_os" "${id} ${version}" || return 1
        fi
        [[ "$id" == "ubuntu" && "$version" == "22.04" ]] && allow_empty=1
    else
        dns::check::emit "unsupported_os" "unknown" || return 1
    fi

    local resolved_active
    if resolved_active=$(dns::state::unit_property "$DNS_RESOLVED_SERVICE" "ActiveState"); then
        if [[ "$resolved_active" != "active" ]]; then
            dns::check::emit "resolved_inactive" || return 1
        fi
    else
        dns::check::emit "runtime_unavailable" || return 1
        resolved_active="unavailable"
    fi

    local resolv_target="unavailable"
    if resolv_target=$(readlink -f "$DNS_RESOLV_CONF_PATH") &&
        [[ "$resolv_target" == "$DNS_RESOLVED_STUB_PATH" ]]; then
        :
    else
        dns::check::emit "resolv_conf" "$resolv_target" || return 1
    fi

    dns::runtime::stub_is_listening ||
        dns::check::emit "stub_inactive" ||
        return 1

    local listener
    while IFS= read -r -d '' listener; do
        dns::check::emit "local_resolver" "$listener" || return 1
    done < <(dns::runtime::local_resolvers)

    dns::config::is_owned "$BSSS_DNS_CONFIG_FILE" ||
        dns::check::emit "bsss_config" "$BSSS_DNS_CONFIG_FILE" ||
        return 1

    if dns::config::get_effective | dns::diagnostics::effective_issues; then
        :
    else
        dns::check::emit "effective_unavailable" || return 1
    fi

    if [[ "$resolved_active" != "active" ]]; then
        return
    fi

    local profile="" expected_dns runtime_dns runtime_domains runtime_dot
    local runtime_unavailable=0
    if IFS= read -r -d '' profile < <(dns::config::get_profile); then
        expected_dns=$(dns::profile::get_servers "$profile" | tr -d '\0') || return 1
        if IFS= read -r -d '' runtime_dns < <(dns::runtime::get_global "dns"); then
            [[ "$runtime_dns" == "$expected_dns" || ( "$allow_empty" == "1" && -z "$runtime_dns" ) ]] ||
                dns::check::emit "runtime_dns" "${runtime_dns:-__unset__}" ||
                return 1
        else
            runtime_unavailable=1
        fi
    fi

    if IFS= read -r -d '' runtime_domains < <(dns::runtime::get_global "domain"); then
        [[ "$runtime_domains" == "~." || ( "$allow_empty" == "1" && -z "$runtime_domains" ) ]] ||
            dns::check::emit "runtime_domains" "${runtime_domains:-__unset__}" ||
            return 1
    else
        runtime_unavailable=1
    fi
    if IFS= read -r -d '' runtime_dot < <(dns::runtime::get_global "dnsovertls"); then
        [[ "$runtime_dot" == "yes" || ( "$allow_empty" == "1" && -z "$runtime_dot" ) ]] ||
            dns::check::emit "runtime_dot" "${runtime_dot:-__unset__}" ||
            return 1
    else
        runtime_unavailable=1
    fi

    local route_record link domain
    while IFS= read -r -d '' route_record; do
        [[ "$route_record" == *$'\t'* && "${route_record#*$'\t'}" != *$'\t'* ]] || return 1
        link="${route_record%%$'\t'*}"
        domain="${route_record#*$'\t'}"
        dns::check::emit "route_domain" "$link" "$domain" || return 1
    done < <(dns::runtime::route_domains)

    if (( runtime_unavailable == 1 )); then
        dns::check::emit "runtime_unavailable"
    fi
}

# @type:        Validator
# @description: Checks whether diagnostics found no DNS protection issue
# @stdin:       None
# @stdout:      None
# @exit_code:   0 no issues
#               1 one or more issues or diagnostic failure
dns::diagnostics::is_protected() {
    if dns::diagnostics::issues | gawk '
        BEGIN { RS = "\0" }
        NF { found = 1 }
        END { exit found ? 1 : 0 }
    '; then
        return
    fi
    return 1
}
