#!/bin/bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/bsss-dns-orchestrator-test.XXXXXX")"
trap 'rm -rf "$TEST_TMP"' EXIT

readonly DNS_PROFILE_GOOGLE_CLOUDFLARE="google-cloudflare"
readonly BSSS_DNS_CONFIG_FILE="${TEST_TMP}/99-bsss-dot.conf"
readonly BSSS_DNS_ROLLBACK_FILE="${BSSS_DNS_CONFIG_FILE}.bsss_backup"
DNS_PREPARE_LOCK_FD=""
CALL_LOG="${TEST_TMP}/calls"
DIRECT_ARTIFACTS=0

source "${PROJECT_ROOT}/modules/helpers/dns/check.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/orchestrator.sh"

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
# @description: Checks the exact call log
# @params:      expected Expected lines (string\n)
#               label Assertion label (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 log matches
#               1 log differs
test::assert::calls() {
    local actual
    actual=$(cat "$CALL_LOG")
    [[ "$actual" == "$1" ]] ||
        test::fail "$2: expected [$1], got [$actual]"
}

dns::recovery::lock() {
    printf 'lock\n' >> "$CALL_LOG"
    DNS_PREPARE_LOCK_FD="9"
}

dns::recovery::unlock() {
    printf 'unlock\n' >> "$CALL_LOG"
    DNS_PREPARE_LOCK_FD=""
}

dns::recovery::has_artifacts() {
    (( DIRECT_ARTIFACTS == 1 ))
}

dns::resolved::apply() {
    printf 'resolved-apply:%s\n' "$1" >> "$CALL_LOG"
}

dns::resolved::remove() {
    printf 'resolved-remove\n' >> "$CALL_LOG"
}

dns::resolved::recover() {
    printf 'resolved-recover\n' >> "$CALL_LOG"
}

dns::prepare::apply() {
    printf 'prepare-apply:%s\n' "$1" >> "$CALL_LOG"
}

dns::prepare::recover() {
    printf 'prepare-recover\n' >> "$CALL_LOG"
}

: > "$CALL_LOG"
dns::orchestrator::apply "resolved-stub" "$DNS_PROFILE_GOOGLE_CLOUDFLARE"
test::assert::calls $'lock\nresolved-apply:google-cloudflare\nunlock' "resolved apply lock"

: > "$CALL_LOG"
dns::orchestrator::apply "networkd-direct" "$DNS_PROFILE_GOOGLE_CLOUDFLARE"
test::assert::calls "prepare-apply:google-cloudflare" "direct apply dispatch"

: > "$CALL_LOG"
dns::orchestrator::remove
test::assert::calls $'lock\nresolved-remove\nunlock' "resolved remove lock"

: > "$CALL_LOG"
touch "$BSSS_DNS_ROLLBACK_FILE"
dns::orchestrator::recover
test::assert::calls $'lock\nresolved-recover\nunlock' "snapshot recovery dispatch"
rm "$BSSS_DNS_ROLLBACK_FILE"

: > "$CALL_LOG"
DIRECT_ARTIFACTS=1
dns::orchestrator::recover
test::assert::calls "prepare-recover" "direct recovery dispatch"

touch "$BSSS_DNS_ROLLBACK_FILE"
if blocker=$(dns::orchestrator::recover | tr '\0' '\n'); then
    test::fail "mixed interrupted state was accepted"
else
    [[ "$?" == "4" ]] || test::fail "mixed interrupted state returned the wrong status"
fi
[[ "$blocker" == $'recovery_inconsistent\t' ]] ||
    test::fail "mixed interrupted state emitted the wrong blocker"
rm "$BSSS_DNS_ROLLBACK_FILE"
DIRECT_ARTIFACTS=0

: > "$CALL_LOG"
DNS_PREPARE_LOCK_FD="9"
touch "$BSSS_DNS_CONFIG_FILE"
dns::orchestrator::dismantle
test::assert::calls "resolved-remove" "full rollback dismantle"
[[ "$DNS_PREPARE_LOCK_FD" == "9" ]] ||
    test::fail "full rollback dismantle released its caller-owned lock"

dns::presentation::execute() {
    printf 'auto:%s\n' "$*" >> "$CALL_LOG"
}

source "${PROJECT_ROOT}/modules/helpers/auto-setup.sh"
: > "$CALL_LOG"
auto::dns::configure "$DNS_PROFILE_GOOGLE_CLOUDFLARE"
test::assert::calls \
    "auto:dns::orchestrator::apply resolved-stub google-cloudflare" \
    "automatic DNS dispatch"

for production_file in \
    modules/dns-check.sh \
    modules/dns-modify.sh \
    modules/auto-setup.sh \
    modules/full-rollback-modify.sh \
    utils/rollback.sh; do
    grep -Fq 'modules/helpers/dns/facade.sh' "${PROJECT_ROOT}/${production_file}" ||
        test::fail "${production_file} does not source the DNS facade"
    if grep -Fq 'modules/helpers/dns.sh' "${PROJECT_ROOT}/${production_file}"; then
        test::fail "${production_file} still sources the legacy DNS helper"
    fi
done

printf 'All DNS orchestration tests passed\n'
