#!/bin/bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/bsss-dns-state-test.XXXXXX")"
trap 'rm -rf "$TEST_TMP"' EXIT

readonly DNS_RESOLV_CONF_PATH="${TEST_TMP}/etc/resolv.conf"
readonly DNS_RESOLVED_STUB_PATH="${TEST_TMP}/run/systemd/resolve/stub-resolv.conf"
readonly DNS_RESOLVED_SERVICE="systemd-resolved.service"
readonly DNS_NETWORKD_SERVICE="systemd-networkd.service"
readonly DNS_NETWORK_MANAGER_SERVICE="NetworkManager.service"
readonly DNS_PREPARE_DIR="${TEST_TMP}/var/lib/bsss/dns-resolver-prepare"
readonly DNS_PREPARE_STAGING_DIR="${TEST_TMP}/var/lib/bsss/.dns-resolver-prepare.new"
readonly DNS_PREPARE_CLEANUP_DIR="${TEST_TMP}/var/lib/bsss/.dns-resolver-prepare.cleanup"
readonly DNS_PREPARE_TEMP_LINK="${TEST_TMP}/etc/.resolv.conf.bsss_prepare"
readonly BSSS_DNS_ROLLBACK_FILE="${TEST_TMP}/etc/systemd/resolved.conf.d/99-bsss-dot.conf.bsss_backup"

MOCK_RESOLVED_LOAD="loaded"
MOCK_RESOLVED_ENABLED="disabled"
MOCK_RESOLVED_ACTIVE="inactive"
MOCK_RESOLVED_SUBSTATE="dead"
MOCK_NETWORKD_ACTIVE="active"
MOCK_NETWORKD_SUBSTATE="running"
MOCK_NETWORK_MANAGER_ACTIVE="inactive"
MOCK_FAILED_PROPERTY=""

mkdir -p \
    "$(dirname "$DNS_RESOLV_CONF_PATH")" \
    "$(dirname "$DNS_RESOLVED_STUB_PATH")" \
    "$(dirname "$DNS_PREPARE_DIR")"
touch "$DNS_RESOLVED_STUB_PATH"

source "${PROJECT_ROOT}/modules/helpers/dns/facade.sh"

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

# @type:        Source
# @description: Mocks one systemd unit property
# @params:      service Unit name (string) without a terminator
#               property Property name (string) without a terminator
# @stdin:       None
# @stdout:      property_value\n
# @exit_code:   0 property emitted
#               1 configured inspection failure or unknown property
dns::state::unit_property() {
    local service="$1"
    local property="$2"
    local identity="${service}:${property}"

    [[ "$identity" != "$MOCK_FAILED_PROPERTY" ]] || return 1
    case "$identity" in
        "${DNS_RESOLVED_SERVICE}:LoadState") printf '%s\n' "$MOCK_RESOLVED_LOAD" ;;
        "${DNS_RESOLVED_SERVICE}:UnitFileState") printf '%s\n' "$MOCK_RESOLVED_ENABLED" ;;
        "${DNS_RESOLVED_SERVICE}:ActiveState") printf '%s\n' "$MOCK_RESOLVED_ACTIVE" ;;
        "${DNS_RESOLVED_SERVICE}:SubState") printf '%s\n' "$MOCK_RESOLVED_SUBSTATE" ;;
        "${DNS_NETWORKD_SERVICE}:ActiveState") printf '%s\n' "$MOCK_NETWORKD_ACTIVE" ;;
        "${DNS_NETWORKD_SERVICE}:SubState") printf '%s\n' "$MOCK_NETWORKD_SUBSTATE" ;;
        "${DNS_NETWORK_MANAGER_SERVICE}:ActiveState") printf '%s\n' "$MOCK_NETWORK_MANAGER_ACTIVE" ;;
        *) return 1 ;;
    esac
}

# @type:        Source
# @description: Emits a complete direct-mode fact fixture
# @stdin:       None
# @stdout:      key<TAB>value\0 records
# @exit_code:   0 facts emitted
test::facts::direct() {
    dns::mode::emit_fact "prepare_artifacts" "no"
    dns::mode::emit_fact "resolv_conf_type" "regular"
    dns::mode::emit_fact "resolv_conf_target" "unavailable"
    dns::mode::emit_fact "resolved_active" "inactive"
    dns::mode::emit_fact "resolved_load" "loaded"
    dns::mode::emit_fact "resolved_enabled" "disabled"
    dns::mode::emit_fact "resolved_substate" "dead"
    dns::mode::emit_fact "networkd_active" "active"
    dns::mode::emit_fact "networkd_substate" "running"
    dns::mode::emit_fact "network_manager_active" "inactive"
}

mode=$(test::facts::direct | dns::mode::detect | tr -d '\0')
test::assert::equals "networkd-direct" "$mode" "pure direct-mode detection"

mode=$(
    {
        dns::mode::emit_fact "prepare_artifacts" "no"
        dns::mode::emit_fact "resolv_conf_type" "symlink"
        dns::mode::emit_fact "resolv_conf_target" "$DNS_RESOLVED_STUB_PATH"
        dns::mode::emit_fact "resolved_active" "active"
    } | dns::mode::detect | tr -d '\0'
)
test::assert::equals "resolved-stub" "$mode" "pure stub-mode detection"

mode=$(dns::mode::emit_fact "prepare_artifacts" "yes" | dns::mode::detect | tr -d '\0')
test::assert::equals "interrupted" "$mode" "interrupted-mode precedence"

mode=$(
    {
        dns::mode::emit_fact "prepare_artifacts" "no"
        dns::mode::emit_fact "resolv_conf_type" "missing"
        dns::mode::emit_fact "resolv_conf_target" "unavailable"
        dns::mode::emit_fact "resolved_active" "inactive"
    } | dns::mode::detect | tr -d '\0'
)
test::assert::equals "unsupported" "$mode" "unsupported-mode detection"

if dns::mode::emit_fact "prepare_artifacts" "no" | dns::mode::detect >/dev/null; then
    test::fail "incomplete facts were accepted"
fi

if printf 'prepare_artifacts\0' | dns::mode::detect >/dev/null; then
    test::fail "fact without a tab separator was accepted"
fi

if printf 'prepare_artifacts\tno\textra\0' | dns::mode::detect >/dev/null; then
    test::fail "fact with an extra tab separator was accepted"
fi

if printf 'prepare_artifacts\tno\nextra\0' | dns::mode::detect >/dev/null; then
    test::fail "fact with a multiline value was accepted"
fi

if {
    test::facts::direct
    printf 'unterminated'
} | dns::mode::detect >/dev/null; then
    test::fail "unterminated fact stream was accepted"
fi

if {
    test::facts::direct
    dns::mode::emit_fact "resolved_active" "active"
} | dns::mode::detect >/dev/null; then
    test::fail "duplicate facts were accepted"
fi

printf '%s\n' 'nameserver 8.8.8.8' > "$DNS_RESOLV_CONF_PATH"
mode=$(dns::mode::get | tr -d '\0')
test::assert::equals "networkd-direct" "$mode" "direct mode from system facts"
dns::state::direct_baseline ||
    test::fail "physical direct baseline was rejected"
mkdir -p "$DNS_PREPARE_STAGING_DIR"
dns::state::direct_baseline ||
    test::fail "recovery artifact changed physical direct baseline"
mode=$(dns::mode::get | tr -d '\0')
test::assert::equals "interrupted" "$mode" "artifact still changes public mode"
rm -r "$DNS_PREPARE_STAGING_DIR"

rm "$DNS_RESOLV_CONF_PATH"
ln -s "$DNS_RESOLVED_STUB_PATH" "$DNS_RESOLV_CONF_PATH"
MOCK_RESOLVED_ACTIVE="active"
MOCK_FAILED_PROPERTY="${DNS_NETWORK_MANAGER_SERVICE}:ActiveState"
mode=$(dns::mode::get | tr -d '\0')
test::assert::equals "resolved-stub" "$mode" "stub mode ignores irrelevant direct probes"
dns::state::resolved_stub ||
    test::fail "physical resolved stub was rejected"

mkdir -p "$(dirname "$BSSS_DNS_ROLLBACK_FILE")"
touch "$BSSS_DNS_ROLLBACK_FILE"
mode=$(dns::mode::get | tr -d '\0')
test::assert::equals "interrupted" "$mode" "resolved snapshot changes public mode"
dns::state::resolved_stub ||
    test::fail "resolved snapshot changed physical stub state"
rm "$BSSS_DNS_ROLLBACK_FILE"

mkdir -p "$DNS_PREPARE_STAGING_DIR"
MOCK_FAILED_PROPERTY="${DNS_RESOLVED_SERVICE}:ActiveState"
mode=$(dns::mode::get | tr -d '\0')
test::assert::equals "interrupted" "$mode" "interrupted mode ignores unavailable runtime"
rm -r "$DNS_PREPARE_STAGING_DIR"

rm "$DNS_RESOLV_CONF_PATH"
printf '%s\n' 'nameserver 8.8.8.8' > "$DNS_RESOLV_CONF_PATH"
MOCK_RESOLVED_ACTIVE="inactive"
MOCK_FAILED_PROPERTY="${DNS_NETWORKD_SERVICE}:SubState"
if dns::mode::get >/dev/null; then
    test::fail "required inspection failure was converted to an unsupported mode"
else
    status=$?
fi
test::assert::equals "1" "$status" "required inspection failure status"

MOCK_FAILED_PROPERTY=""
MOCK_NETWORKD_ACTIVE="inactive"
if mode=$(dns::mode::get | tr -d '\0'); then
    test::fail "observable unsupported state returned success"
else
    status=$?
fi
test::assert::equals "unsupported" "$mode" "observable unsupported state"
test::assert::equals "4" "$status" "observable unsupported status"

rm "$DNS_RESOLV_CONF_PATH"
ln -s "${TEST_TMP}/missing-target" "$DNS_RESOLV_CONF_PATH"
if mode=$(dns::mode::get | tr -d '\0'); then
    test::fail "broken resolver symlink returned success"
else
    status=$?
fi
test::assert::equals "unsupported" "$mode" "broken resolver symlink"
test::assert::equals "4" "$status" "broken resolver symlink status"

printf 'All DNS mode state tests passed\n'
