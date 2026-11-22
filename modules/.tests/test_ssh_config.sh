#!/usr/bin/env bash

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ../..)"
readonly TEST_TMP_DIR="$(mktemp -d)"
SSH_CONFIG_FILE="${TEST_TMP_DIR}/sshd_config"
SSH_CONFIGD_DIR="${TEST_TMP_DIR}/sshd_config.d"
BSSS_SSH_CONFIG_FILE_MASK='*bsss-ssh-port.conf'

trap 'rm -rf "$TEST_TMP_DIR"' EXIT
mkdir -p "$SSH_CONFIGD_DIR"

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

log_warn() {
    printf '%s\n' "$*" >> "${TEST_TMP_DIR}/warnings"
}

common::preconfiguration::show() {
    printf 'guide\n' >> "${TEST_TMP_DIR}/guide"
}

source "${PROJECT_ROOT}/modules/helpers/ssh-config.sh"

cat > "$SSH_CONFIG_FILE" <<EOF
# Standard Ubuntu layout
Include ${SSH_CONFIGD_DIR}/*.conf
PasswordAuthentication yes
EOF
ssh::config::standard_include_is_early ||
    test::fail "early standard Include was rejected"

cat > "$SSH_CONFIG_FILE" <<EOF
PasswordAuthentication yes
Include ${SSH_CONFIGD_DIR}/*.conf
EOF
if ssh::config::standard_include_is_early; then
    test::fail "late Include was accepted"
fi

printf 'Port 22\n' > "$SSH_CONFIG_FILE"
: > "${TEST_TMP_DIR}/warnings"
: > "${TEST_TMP_DIR}/guide"
if ssh::config::preflight_dropins; then
    test::fail "missing Include passed preflight"
else
    [[ "$?" == "4" ]] || test::fail "missing Include returned the wrong status"
fi
[[ "$(wc -l < "${TEST_TMP_DIR}/guide")" == "1" ]] ||
    test::fail "missing Include did not display the guide once"

cat > "$SSH_CONFIG_FILE" <<EOF
Include ${SSH_CONFIGD_DIR}/*.conf
EOF
printf 'Port 22\n' > "${SSH_CONFIGD_DIR}/60-provider.conf"
printf 'Port 44000\n' > "${SSH_CONFIGD_DIR}/40-bsss-ssh-port.conf"

rules=$(ssh::config::foreign_ports | tr '\0' '\n')
[[ "$rules" == *"60-provider.conf:1:Port 22"* ]] ||
    test::fail "foreign Port rule was not emitted"
[[ "$rules" != *"40-bsss-ssh-port.conf"* ]] ||
    test::fail "BSSS Port rule was emitted as foreign"

: > "${TEST_TMP_DIR}/guide"
if ssh::config::preflight_port_change; then
    test::fail "foreign Port rule passed preflight"
else
    [[ "$?" == "4" ]] || test::fail "foreign Port returned the wrong status"
fi
[[ "$(wc -l < "${TEST_TMP_DIR}/guide")" == "1" ]] ||
    test::fail "foreign Port did not display the guide once"

rm "${SSH_CONFIGD_DIR}/60-provider.conf"
ssh::config::preflight_port_change ||
    test::fail "standard drop-in layout failed port preflight"

printf 'PASS: SSH configuration preflight\n'
