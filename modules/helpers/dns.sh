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
# @description: Renders the BSSS systemd-resolved drop-in for a profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      resolved.conf content (text\n)
# @exit_code:   0 configuration rendered
#               1 unsupported profile
dns::config::render() {
    local servers

    servers=$(dns::profile::get_servers "$1" | tr -d '\0')
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

    effective=$(dns::config::get_effective)
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
        $5 ~ /^127\.0\.0\.53(%[^:]*)?:53$/ {
            found = 1
            exit
        }
        END { exit found ? 0 : 1 }
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

    if ! systemctl is-active --quiet "$DNS_RESOLVED_SERVICE"; then
        dns::issue::emit "resolved_inactive"
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

    local effective
    if effective=$(dns::config::get_effective 2>/dev/null); then
        local -A settings=()
        local key value
        while IFS=$'\t' read -r key value; do
            settings["$key"]="$value"
        done <<< "$effective"

        case "${settings[DNS]:-__unset__}" in
            "$DNS_SERVERS_GOOGLE_CLOUDFLARE"|"$DNS_SERVERS_YANDEX_GOOGLE") ;;
            *) dns::issue::emit "profile_unknown" "${settings[DNS]:-__unset__}" ;;
        esac
        [[ "${settings[FallbackDNS]:-__unset__}" == "" ]] || \
            dns::issue::emit "fallback_dns" "${settings[FallbackDNS]:-__unset__}"
        [[ "${settings[Domains]:-__unset__}" == "~." ]] || \
            dns::issue::emit "domains" "${settings[Domains]:-__unset__}"
        [[ "${settings[DNSOverTLS]:-__unset__}" == "yes" ]] || \
            dns::issue::emit "dot_mode" "${settings[DNSOverTLS]:-__unset__}"
        [[ "${settings[DNSSEC]:-__unset__}" == "no" ]] || \
            dns::issue::emit "dnssec" "${settings[DNSSEC]:-__unset__}"
        [[ "${settings[LLMNR]:-__unset__}" == "no" ]] || \
            dns::issue::emit "llmnr" "${settings[LLMNR]:-__unset__}"
        [[ "${settings[MulticastDNS]:-__unset__}" == "no" ]] || \
            dns::issue::emit "multicast_dns" "${settings[MulticastDNS]:-__unset__}"
    else
        dns::issue::emit "effective_unavailable"
    fi

    local domains
    if domains=$(resolvectl --no-pager domain 2>/dev/null); then
        dns::runtime::route_issues <<< "$domains"
    else
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
            profile_unknown|fallback_dns|domains|dot_mode|dnssec|llmnr|multicast_dns)
                arg1=$(dns::log::display_value "$arg1")
                ;;
        esac
        case "$code" in
            missing_command)       log_info_simple_tab "$(_ "dns.issue.missing_command" "$arg1")" ;;
            unsupported_os)        log_info_simple_tab "$(_ "dns.issue.unsupported_os" "$arg1")" ;;
            resolved_inactive)     log_info_simple_tab "$(_ "dns.issue.resolved_inactive")" ;;
            resolv_conf)           log_info_simple_tab "$(_ "dns.issue.resolv_conf" "$arg1")" ;;
            stub_inactive)         log_info_simple_tab "$(_ "dns.issue.stub_inactive")" ;;
            effective_unavailable) log_info_simple_tab "$(_ "dns.issue.effective_unavailable")" ;;
            profile_unknown)       log_info_simple_tab "$(_ "dns.issue.profile_unknown" "$arg1")" ;;
            fallback_dns)          log_info_simple_tab "$(_ "dns.issue.fallback_dns" "$arg1")" ;;
            domains)               log_info_simple_tab "$(_ "dns.issue.domains" "$arg1")" ;;
            dot_mode)              log_info_simple_tab "$(_ "dns.issue.dot_mode" "$arg1")" ;;
            dnssec)                log_info_simple_tab "$(_ "dns.issue.dnssec" "$arg1")" ;;
            llmnr)                 log_info_simple_tab "$(_ "dns.issue.llmnr" "$arg1")" ;;
            multicast_dns)         log_info_simple_tab "$(_ "dns.issue.multicast_dns" "$arg1")" ;;
            route_domain)          log_info_simple_tab "$(_ "dns.issue.route_domain" "$arg1" "$arg2")" ;;
            runtime_unavailable)   log_info_simple_tab "$(_ "dns.issue.runtime_unavailable")" ;;
            *)                     log_info_simple_tab "$(_ "dns.issue.unknown" "$code")" ;;
        esac
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
        return
    fi

    log_warn "$(_ "dns.status.unconfirmed")"
    dns::status::issues | dns::log::issues
}
