#!/bin/bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DNS_QUERY_TIMEOUT_SECONDS=1

source "${PROJECT_ROOT}/modules/helpers/dns/runtime.sh"

# @type:        Sink
# @description: Fails the current test
# @params:      message Failure message (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   1 always
test::fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# @type:        Validator
# @description: Compares two strings
# @params:      expected Expected value (string) without a terminator
#               actual Actual value (string) without a terminator
#               label Assertion label (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 values match
#               1 values differ
test::assert::equals() {
    [[ "$2" == "$1" ]] || test::fail "$3: expected [$1], got [$2]"
}

SS_OUTPUT=""
RESOLVECTL_MODE=""

ss() {
    printf '%s\n' "$SS_OUTPUT"
}

resolvectl() {
    case "${*: -1}" in
        domain)
            printf '%s\n' \
                'Global: ~.' \
                'Link 2 (ens3): ~corp.example example.test'
            ;;
        dns)
            printf 'Global: 8.8.8.8 1.1.1.1\n'
            ;;
        dnsovertls)
            printf 'Global: yes\n'
            ;;
        example.com)
            [[ "$RESOLVECTL_MODE" != "fail" ]] || return 1
            printf 'example.com: 192.0.2.1\n'
            ;;
        *) return 1 ;;
    esac
}

timeout() {
    shift
    "$@"
}

getent() {
    [[ "$1" == "ahosts" && "$2" == "example.com" ]] || return 1
    printf '192.0.2.1 STREAM example.com\n'
}

SS_OUTPUT=$'udp UNCONN 0 0 127.0.0.53:53 0.0.0.0:*\ntcp LISTEN 0 4096 127.0.0.53:53 0.0.0.0:*'
dns::runtime::stub_is_listening ||
    test::fail "complete resolved stub listeners were rejected"

SS_OUTPUT=$'udp UNCONN 0 0 127.0.0.53:53 0.0.0.0:*\ntcp LISTEN 0 4096 10.0.0.1:53 0.0.0.0:*'
if dns::runtime::stub_is_listening; then
    test::fail "incomplete resolved stub listeners were accepted"
fi
listeners=$(dns::runtime::local_resolvers | tr '\0' '\n')
test::assert::equals "10.0.0.1:53" "$listeners" "foreign listener source"

domains=$(dns::runtime::route_domains | tr '\0' '\n')
test::assert::equals $'ens3\t~corp.example\nens3\texample.test' "$domains" "route domain source"

global_dns=$(dns::runtime::get_global "dns" | tr -d '\0')
test::assert::equals "8.8.8.8 1.1.1.1" "$global_dns" "global DNS source"
global_dot=$(dns::runtime::get_global "dnsovertls" | tr -d '\0')
test::assert::equals "yes" "$global_dot" "global DoT source"
if dns::runtime::get_global "unsupported" >/dev/null; then
    test::fail "unsupported runtime property was accepted"
fi

dns::runtime::query_strict "example.com" ||
    test::fail "strict runtime query failed"
dns::runtime::query_libc "example.com" ||
    test::fail "libc runtime query failed"
RESOLVECTL_MODE="fail"
if dns::runtime::query_strict "example.com"; then
    test::fail "failed strict runtime query was accepted"
fi

printf 'All DNS runtime component tests passed\n'
