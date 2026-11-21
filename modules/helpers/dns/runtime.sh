# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Checks whether the standard resolved stub listens on UDP and TCP
# @stdin:       None
# @stdout:      None
# @exit_code:   0 both listeners found
#               1 listener state differs or inspection failed
dns::runtime::stub_is_listening() {
    ss -H -lntu | gawk '
        $5 ~ /^127\.0\.0\.53(%[^:]*)?:53$/ && $1 == "udp" { udp = 1 }
        $5 ~ /^127\.0\.0\.53(%[^:]*)?:53$/ && $1 == "tcp" { tcp = 1 }
        END { exit udp && tcp ? 0 : 1 }
    '
}

# @type:        Source
# @description: Lists port 53 listeners other than supported resolved stubs
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
# @description: Emits per-link DNS route domains
# @stdin:       resolvectl domain output (text\n)
# @stdout:      link<TAB>domain\0 (0..N)
# @exit_code:   0 parsed
#               $? gawk failure
dns::runtime::parse_route_domains() {
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
                    print link "\t" values[i]
                }
            }
        }
    '
}

# @type:        Source
# @description: Reads and parses per-link DNS route domains
# @stdin:       None
# @stdout:      link<TAB>domain\0 (0..N)
# @exit_code:   0 runtime inspected
#               1 resolvectl unavailable
#               $? parser failure
dns::runtime::route_domains() {
    local output

    output=$(resolvectl --no-pager domain 2>/dev/null) || return 1
    dns::runtime::parse_route_domains <<< "$output"
}

# @type:        Source
# @description: Returns one normalized Global resolvectl property
# @params:      property Resolvectl property command (string) without a terminator
# @stdin:       None
# @stdout:      value\0
# @exit_code:   0 Global value emitted
#               1 unsupported property, command failure, or missing Global row
#               $? parser failure
dns::runtime::get_global() {
    local property="$1"
    local output

    case "$property" in
        dns|domain|dnsovertls) ;;
        *) return 1 ;;
    esac
    output=$(resolvectl --no-pager "$property" 2>&1) || return 1
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

# @type:        Validator
# @description: Performs a bounded uncached DNS protocol query through resolved
# @params:      name DNS name (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 query succeeded with a nonempty response
#               1 query failed or returned no data
dns::runtime::query_strict() {
    local output

    output=$(
        timeout "${DNS_QUERY_TIMEOUT_SECONDS}s" resolvectl query \
            --protocol=dns \
            --synthesize=no \
            --cache=no \
            "$1" 2>&1
    ) || return 1
    [[ -n "$output" ]]
}

# @type:        Validator
# @description: Performs a bounded libc resolver query
# @params:      name DNS name (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 query succeeded with a nonempty response
#               1 query failed or returned no data
dns::runtime::query_libc() {
    local output

    output=$(timeout "${DNS_QUERY_TIMEOUT_SECONDS}s" getent ahosts "$1" 2>&1) || return 1
    [[ -n "$output" ]]
}
