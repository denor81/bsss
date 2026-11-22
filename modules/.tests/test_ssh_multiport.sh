#!/usr/bin/env bash

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ../..)"
readonly TEST_TMP_DIR="$(mktemp -d)"
readonly PORTS_FILE="${TEST_TMP_DIR}/ports"

trap 'rm -rf "$TEST_TMP_DIR"' EXIT

test::fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

_() {
    printf '%s' "$1"
}

log_info() {
    :
}

log_error() {
    :
}

ssh::port::get_from_ss() {
    tr ' ' '\0' < "$PORTS_FILE"
}

source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"
source "${PROJECT_ROOT}/modules/helpers/auto-setup.sh"

ssh::port::get_configured() {
    tr ' ' '\0' < "$PORTS_FILE"
}

ssh::port::generate_free_random_port() {
    printf '45000\0'
}

ssh::log::guard_instructions() {
    :
}

ssh::rule::reset_and_pass() {
    cat
}

ufw::rule::reset_and_pass() {
    cat
}

INSTALL_EFFECTIVE=1
ssh::port::install_new() {
    local port

    read -r -d '' port
    (( INSTALL_EFFECTIVE == 0 )) || printf '22 %s' "$port" > "$PORTS_FILE"
}

sys::service::restart() {
    :
}

ssh::port::wait_for_up() {
    ssh::port::list_contains "$(tr ' ' ',' < "$PORTS_FILE")," "$1"
}

printf '22 44000' > "$PORTS_FILE"
ssh::port::is_consistent_nondefault ||
    test::fail "matching multiple SSH ports were rejected"
auto::ssh::configure ||
    test::fail "consistent multiple SSH ports were reconfigured"
[[ "$(cat "$PORTS_FILE")" == "22 44000" ]] ||
    test::fail "consistent multiple SSH ports were changed"

printf '22' > "$PORTS_FILE"
auto::ssh::configure ||
    test::fail "new SSH port was rejected beside a foreign port"
[[ "$(cat "$PORTS_FILE")" == "22 45000" ]] ||
    test::fail "new SSH port was not preserved beside a foreign port"

printf '22' > "$PORTS_FILE"
INSTALL_EFFECTIVE=0
if auto::ssh::configure; then
    test::fail "missing generated SSH port passed post-validation"
fi

printf 'PASS: SSH multiple-port handling\n'
