# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

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
# @description: Renders the complete BSSS systemd-resolved drop-in
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
#               1 missing, linked, unreadable, or foreign file
dns::config::is_owned() {
    local path="$1"

    [[ -f "$path" && ! -L "$path" && -r "$path" ]] &&
        grep -Fxq "# $BSSS_MARKER_COMMENT" "$path"
}

# @type:        Filter
# @description: Resolves managed settings from concatenated resolved.conf files
# @stdin:       systemd-analyze cat-config output (text\n)
# @stdout:      setting<TAB>value\0 (7 records)
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
                printf "%s\t%s%c", key, (seen[key] ? values[key] : "__unset__"), 0
            }
        }
    '
}

# @type:        Source
# @description: Reads and parses effective systemd-resolved configuration
# @stdin:       None
# @stdout:      setting<TAB>value\0 (7 records)
# @exit_code:   0 configuration parsed
#               $? systemd-analyze or parser failure
dns::config::get_effective() {
    systemd-analyze cat-config systemd/resolved.conf | dns::config::parse_effective
}

# @type:        Validator
# @description: Checks whether a resolved.conf file actively sets BSSS-managed values
# @params:      path resolved.conf path (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 one or more managed settings found
#               1 no managed settings found
#               2 unreadable or unsupported file object
#               $? gawk failure
dns::config::has_managed_setting() {
    local path="$1"

    [[ -f "$path" && -r "$path" ]] || return 2
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
    ' "$path"
}

# @type:        Source
# @description: Emits systemd-resolved drop-in search directories
# @stdin:       None
# @stdout:      path\0 (5 records)
# @exit_code:   0 paths emitted
dns::config::search_dirs() {
    printf '%s\0' \
        "/usr/lib/systemd/resolved.conf.d" \
        "/usr/local/lib/systemd/resolved.conf.d" \
        "/lib/systemd/resolved.conf.d" \
        "/run/systemd/resolved.conf.d" \
        "/etc/systemd/resolved.conf.d"
}

# @type:        Source
# @description: Lists later-sorting foreign drop-ins that can override BSSS DNS values
# @stdin:       None
# @stdout:      path\0 (0..N)
# @exit_code:   0 search completed
#               1 inspection failure
dns::config::late_conflicts() (
    local LC_ALL=C
    local dir path name status
    local -a dirs=()

    mapfile -d '' -t dirs < <(dns::config::search_dirs)
    shopt -s nullglob
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        [[ -r "$dir" && -x "$dir" ]] || return 1
        for path in "$dir"/*.conf; do
            [[ "$path" != *[$'\t\n']* ]] || return 1
            name=$(basename "$path") || return 1
            [[ "$name" > "$BSSS_DNS_CONFIG_FILE_NAME" ]] || continue
            if dns::config::has_managed_setting "$path"; then
                printf '%s\0' "$path"
            else
                status=$?
                (( status == 1 )) || return 1
            fi
        done
    done
)

# @type:        Validator
# @description: Checks whether the BSSS DNS file already matches a profile exactly
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 exact content match
#               1 target missing, foreign, different, or profile unsupported
dns::config::matches_profile() {
    dns::config::is_owned "$BSSS_DNS_CONFIG_FILE" || return 1
    cmp --silent "$BSSS_DNS_CONFIG_FILE" <(dns::config::render "$1")
}

# @type:        Filter
# @description: Identifies a supported profile from effective resolved settings
# @stdin:       setting<TAB>value\0 (7 records)
# @stdout:      profile\0
# @exit_code:   0 supported profile identified
#               1 malformed, incomplete, or custom settings
dns::config::profile_filter() {
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
        "$DNS_SERVERS_GOOGLE_CLOUDFLARE") printf '%s\0' "$DNS_PROFILE_GOOGLE_CLOUDFLARE" ;;
        "$DNS_SERVERS_YANDEX_GOOGLE") printf '%s\0' "$DNS_PROFILE_YANDEX_GOOGLE" ;;
        *) return 1 ;;
    esac
}

# @type:        Source
# @description: Identifies the supported effective resolver profile
# @stdin:       None
# @stdout:      profile\0
# @exit_code:   0 supported profile identified
#               1 inspection, parsing, or profile recognition failure
dns::config::get_profile() {
    local -a statuses

    dns::config::get_effective | dns::config::profile_filter
    statuses=("${PIPESTATUS[@]}")
    (( statuses[0] == 0 && statuses[1] == 0 ))
}
