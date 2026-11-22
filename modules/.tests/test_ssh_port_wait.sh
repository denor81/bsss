#!/usr/bin/env bash

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ../..)"
readonly TEST_TMP_DIR="$(mktemp -d)"
readonly SSH_PORT_CHECK_TIMEOUT=3

trap 'rm -rf "$TEST_TMP_DIR"' EXIT

test::fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

_() {
    local key="$1"
    shift
    printf '%s' "$key"
    (($# == 0)) || printf ':%s' "$*"
}

log_info() {
    printf '%s\n' "$*" >> "${TEST_TMP_DIR}/info"
}

log_error() {
    printf '%s\n' "$*" >> "${TEST_TMP_DIR}/error"
}

sleep() {
    SLEEP_CALLS=$((SLEEP_CALLS + 1))
}

source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"

SUCCESS_AT=1
INSPECTION_ERROR=0
CALL_LOG="${TEST_TMP_DIR}/calls"
ssh::port::get_from_ss() {
    printf 'call\n' >> "$CALL_LOG"
    (( INSPECTION_ERROR == 0 )) || return 2
    local calls
    calls=$(wc -l < "$CALL_LOG")
    (( calls < SUCCESS_AT )) || printf '44000\0'
}

test::reset() {
    : > "$CALL_LOG"
    : > "${TEST_TMP_DIR}/info"
    : > "${TEST_TMP_DIR}/error"
    SLEEP_CALLS=0
    INSPECTION_ERROR=0
}

test::reset
SUCCESS_AT=1
ssh::port::wait_for_up "44000" ||
    test::fail "immediate listener was not detected"
[[ "$SLEEP_CALLS" == "0" ]] || test::fail "immediate listener slept"

test::reset
SUCCESS_AT=3
ssh::port::wait_for_up "44000" ||
    test::fail "delayed listener was not detected"
[[ "$SLEEP_CALLS" == "2" ]] || test::fail "delayed listener sleep count"
grep -q 'ssh.success_port_up:44000 3 2' "${TEST_TMP_DIR}/info" ||
    test::fail "delayed listener accounting"

test::reset
SUCCESS_AT=99
if ssh::port::wait_for_up "44000"; then
    test::fail "missing listener passed"
fi
[[ "$(wc -l < "$CALL_LOG")" == "3" ]] || test::fail "timeout attempt count"
[[ "$SLEEP_CALLS" == "3" ]] || test::fail "timeout duration count"
grep -q 'ssh.error_port_not_up:44000 3 3' "${TEST_TMP_DIR}/error" ||
    test::fail "timeout log accounting"

test::reset
INSPECTION_ERROR=1
if ssh::port::wait_for_up "44000"; then
    test::fail "listener inspection failure passed"
fi
[[ "$(wc -l < "$CALL_LOG")" == "1" ]] || test::fail "inspection retry count"
[[ "$SLEEP_CALLS" == "0" ]] || test::fail "inspection failure slept"
grep -q 'ssh.error_listener_inspection:1' "${TEST_TMP_DIR}/error" ||
    test::fail "inspection failure was not distinguished"

printf 'PASS: SSH port wait\n'
