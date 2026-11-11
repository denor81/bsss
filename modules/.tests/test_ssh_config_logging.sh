#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
readonly PROJECT_ROOT
source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/i18n/en/common.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/.tests/helpers/assertions.sh"

# @type:        Source
# @description: Supplies SSH configuration without reading the host configuration
# @params:      option Expected -T argument (string), without terminator
# @stdin:       None
# @stdout:      configuration_line\n repeated
# @exit_code:   0 success
#               1 unexpected arguments
sshd() {
    [[ "$#" == 1 && "$1" == -T ]] || return 1
    printf '%s\n' "$TEST_SSH_CONFIG"
}

# @type:        Sink
# @description: Captures the real logger's file messages in a test fixture
# @params:      message Formatted file message (string), without terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 success
#               $? fixture write failure
log::to_file() {
    printf '%s\n' "$1" >>"$TEST_WORK_DIR/filelog"
}

# @type:        Sink
# @description: Captures real message types and their configured journal priorities
# @params:      message Log message (string), without terminator
#               type Message type (string), without terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 success
#               $? fixture write failure
log::to_journal() {
    printf '%s|%s|%s\n' "$2" "${JOURNAL_MAP[$2]}" "$1" >>"$TEST_WORK_DIR/journal"
}

# @type:        Orchestrator
# @description: Checks the SSH heading's terminal formatting and unchanged severity
# @params:      pattern SSH parameter filter (string), without terminator
#               type Expected INFO or WARN type (string), without terminator
#               symbol Expected terminal symbol (string), without terminator
#               priority Expected journal priority (string), without terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 assertions passed
#               $? assertion or logging failure
test::ssh::heading() {
    : >"$TEST_WORK_DIR/filelog"
    : >"$TEST_WORK_DIR/journal"
    common::log::current_config "$1" 3>"$TEST_WORK_DIR/terminal"

    local heading
    IFS= read -r heading <"$TEST_WORK_DIR/terminal"
    [[ "$heading" == $'\e[1m'"$3 [$CURRENT_MODULE_NAME] Current SSH configuration [sshd -T]:"$'\e[0m' ]]
    grep -Fxq "[$2] [$CURRENT_MODULE_NAME] Current SSH configuration [sshd -T]:" "$TEST_WORK_DIR/filelog"
    grep -Fxq "$2|$4|Current SSH configuration [sshd -T]:" "$TEST_WORK_DIR/journal"
    test::assert::no_match $'\e' "$TEST_WORK_DIR/filelog" "$TEST_WORK_DIR/journal"
}

# @type:        Orchestrator
# @description: Tests both SSH check headings and default logger output without formatting changes
# @stdin:       None
# @stdout:      result\n
# @exit_code:   0 all assertions passed
#               $? assertion or command failure
main() {
    TEST_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bsss-ssh-logging-tests.XXXXXX")
    trap 'rm -rf "$TEST_WORK_DIR"' EXIT

    TEST_SSH_CONFIG=$'port 22\npubkeyauthentication yes\npasswordauthentication yes\npermitrootlogin yes'
    test::ssh::heading '^port' WARN "$SYMBOL_WARN" warning
    grep -Fxq '[!] port 22' <(tr '\t' ' ' <"$TEST_WORK_DIR/terminal")
    test::ssh::heading '^pubkeyauthentication|^passwordauthentication|^permitrootlogin' WARN "$SYMBOL_WARN" warning
    [[ $(grep -c '^\[!\]' "$TEST_WORK_DIR/terminal") == 2 ]]

    TEST_SSH_CONFIG=$'port 2222\npubkeyauthentication yes\npasswordauthentication no\npermitrootlogin no'
    test::ssh::heading '^port' INFO "$SYMBOL_INFO" info
    test::assert::no_match '^\[!\]' "$TEST_WORK_DIR/terminal"
    test::ssh::heading '^pubkeyauthentication|^passwordauthentication|^permitrootlogin' INFO "$SYMBOL_INFO" info
    test::assert::no_match '^\[!\]' "$TEST_WORK_DIR/terminal"

    LOG_STRICT_MODE=false test::ssh::heading '^port' INFO "$SYMBOL_INFO" info

    log_info 'plain info' 3>"$TEST_WORK_DIR/terminal"
    grep -Fxq "$SYMBOL_INFO [$CURRENT_MODULE_NAME] plain info" "$TEST_WORK_DIR/terminal"
    test::assert::no_match $'\e' "$TEST_WORK_DIR/terminal"
    log_warn 'plain warning' 3>"$TEST_WORK_DIR/terminal"
    grep -Fxq "$SYMBOL_WARN [$CURRENT_MODULE_NAME] plain warning" "$TEST_WORK_DIR/terminal"
    test::assert::no_match $'\e' "$TEST_WORK_DIR/terminal"

    printf 'All SSH configuration logging tests passed.\n'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
