# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Filter
# @description: Validates effective resolved settings against a resolver profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       setting<TAB>value\0 (7 records)
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 effective settings match
#               1 malformed or incomplete input
#               4 setting differs
dns::validate::effective_filter() {
    local profile="$1"
    local record="" key value servers
    local -A settings=()
    local -a keys=(DNS FallbackDNS Domains DNSOverTLS DNSSEC LLMNR MulticastDNS)

    servers=$(dns::profile::get_servers "$profile" | tr -d '\0') || return 1
    while IFS= read -r -d '' record; do
        [[ "$record" == *$'\t'* ]] || return 1
        key="${record%%$'\t'*}"
        value="${record#*$'\t'}"
        [[ -n "$key" && "$key" != *[$'\t\n']* && "$value" != *[$'\t\n']* ]] || return 1
        [[ -z "${settings[$key]+x}" ]] || return 1
        case "$key" in
            DNS|FallbackDNS|Domains|DNSOverTLS|DNSSEC|LLMNR|MulticastDNS) ;;
            *) return 1 ;;
        esac
        settings["$key"]="$value"
        record=""
    done
    [[ -z "$record" ]] || return 1

    for key in "${keys[@]}"; do
        [[ -n "${settings[$key]+x}" ]] || return 1
    done

    local -A expected=(
        [DNS]="$servers"
        [FallbackDNS]=""
        [Domains]="~."
        [DNSOverTLS]="yes"
        [DNSSEC]="no"
        [LLMNR]="no"
        [MulticastDNS]="no"
    )
    for key in "${keys[@]}"; do
        [[ "${settings[$key]}" == "${expected[$key]}" ]] ||
            dns::check::block "effective_mismatch" "$key" "${expected[$key]}" "${settings[$key]}" ||
            return
    done
}

# @type:        Validator
# @description: Reads and validates effective resolved settings
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 effective settings match
#               1 configuration inspection or parsing failed
#               4 setting differs
dns::validate::effective() {
    local profile="$1"
    local -a statuses

    dns::config::get_effective | dns::validate::effective_filter "$profile"
    statuses=("${PIPESTATUS[@]}")
    (( statuses[0] == 0 )) || return 1
    return "${statuses[1]}"
}

# @type:        Validator
# @description: Checks whether empty Global runtime values are allowed on this release
# @stdin:       None
# @stdout:      None
# @exit_code:   0 empty runtime values allowed
#               1 release cannot be inspected
#               4 release requires exact runtime values
dns::validate::allows_empty_global() {
    local record id version

    IFS= read -r -d '' record < <(dns::check::release) || return 1
    [[ "$record" == *$'\t'* && "${record#*$'\t'}" != *$'\t'* ]] || return 1
    id="${record%%$'\t'*}"
    version="${record#*$'\t'}"
    if [[ "$id" == "ubuntu" && "$version" == "22.04" ]]; then
        return
    fi
    return 4
}

# @type:        Validator
# @description: Validates normalized Global resolved runtime values
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 runtime values match
#               1 runtime or release inspection failed
#               4 runtime differs
dns::validate::global_runtime() {
    local profile="$1"
    local expected_dns runtime_dns runtime_domains runtime_dot allow_empty=0 status

    expected_dns=$(dns::profile::get_servers "$profile" | tr -d '\0') || return 1
    runtime_dns=$(dns::runtime::get_global "dns" | tr -d '\0') || return 1
    runtime_domains=$(dns::runtime::get_global "domain" | tr -d '\0') || return 1
    runtime_dot=$(dns::runtime::get_global "dnsovertls" | tr -d '\0') || return 1
    if dns::validate::allows_empty_global; then
        allow_empty=1
    else
        status=$?
        (( status == 4 )) || return 1
    fi

    [[ "$runtime_dns" == "$expected_dns" || ( "$allow_empty" == "1" && -z "$runtime_dns" ) ]] ||
        dns::check::block "runtime_mismatch" "DNS" "$expected_dns" "$runtime_dns" ||
        return
    [[ "$runtime_domains" == "~." || ( "$allow_empty" == "1" && -z "$runtime_domains" ) ]] ||
        dns::check::block "runtime_mismatch" "Domains" "~." "$runtime_domains" ||
        return
    [[ "$runtime_dot" == "yes" || ( "$allow_empty" == "1" && -z "$runtime_dot" ) ]] ||
        dns::check::block "runtime_mismatch" "DNSOverTLS" "yes" "$runtime_dot"
}

# @type:        Validator
# @description: Confirms strict resolved runtime state for a resolver profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 strict runtime state confirmed
#               1 technical or internal failure
#               4 observed state differs
dns::validate::strict_runtime() {
    local profile="$1"

    dns::profile::is_valid "$profile" || return 1
    if ! dns::config::is_owned "$BSSS_DNS_CONFIG_FILE" ||
        ! dns::config::matches_profile "$profile"; then
        dns::check::block "config_mismatch" "$BSSS_DNS_CONFIG_FILE"
        return
    fi
    dns::validate::effective "$profile" || return
    dns::runtime::stub_is_listening ||
        dns::check::block "stub_inactive" ||
        return
    dns::check::local_resolver || return
    dns::check::routes || return
    dns::check::late_conflict || return
    dns::validate::global_runtime "$profile" || return
    dns::runtime::query_strict "$DNS_TEST_DOMAIN" ||
        dns::check::block "strict_query_failed" "$DNS_TEST_DOMAIN" ||
        return
}

# @type:        Validator
# @description: Confirms strict protected DNS state for a resolver profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 protected state confirmed
#               1 technical or internal failure
#               4 observed state differs
dns::validate::protected() {
    local profile="$1"

    dns::profile::is_valid "$profile" || return 1
    dns::state::resolved_stub ||
        dns::check::block "stub_shape_mismatch" ||
        return
    dns::validate::strict_runtime "$profile" || return
    dns::runtime::query_libc "$DNS_TEST_DOMAIN" ||
        dns::check::block "libc_query_failed" "$DNS_TEST_DOMAIN"
}
