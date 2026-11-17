#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"

source "${PROJECT_ROOT}/oneline-runner.sh"
trap - INT EXIT
source "${PROJECT_ROOT}/modules/.tests/helpers/assertions.sh"

INSTALLER_LANG="en"

# @type:        Sink
# @description: Captures an installer log message for assertions
# @params:      level Log level (string), without terminator
#               message Log message (string), without terminator
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
test::runner::log() {
    printf '%s %s\n' "$1" "$2" >&3
}

# @type:        Sink
# @description: Captures informational installer messages
# @params:      message Log message (string), without terminator
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
log_info() {
    test::runner::log INFO "$1"
}

# @type:        Sink
# @description: Captures installer warnings
# @params:      message Log message (string), without terminator
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
log_warn() {
    test::runner::log WARN "$1"
}

# @type:        Sink
# @description: Captures installer errors
# @params:      message Log message (string), without terminator
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
log_error() {
    test::runner::log ERROR "$1"
}

# @type:        Sink
# @description: Captures successful installer operations
# @params:      message Log message (string), without terminator
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
log_success() {
    test::runner::log SUCCESS "$1"
}

# @type:        Validator
# @description: Simulates detection of an installed copy from the scenario state
# @stdin:       None
# @stdout:      None
# @exit_code:   0 installation path exists
#               1 installation path is absent
install::existing::is_detected() {
    [[ "$(cat "$TEST_WORK_DIR/state")" != absent ]]
}

# @type:        Validator
# @description: Simulates validation of an installed BSSS copy
# @stdin:       None
# @stdout:      None
# @exit_code:   0 installation is valid
#               1 installation is invalid
install::existing::is_valid() {
    [[ "$(cat "$TEST_WORK_DIR/state")" != invalid ]]
}

# @type:        Source
# @description: Simulates the generic installation confirmation
# @params:      args Prompt arguments (array), without terminators
# @stdin:       None
# @stdout:      None
# @exit_code:   0 accepted
#               2 cancelled
ui::ask_value() {
    printf 'CONFIRM\n' >&3
    return "${CONFIRM_STATUS:-0}"
}

# @type:        Orchestrator
# @description: Simulates archive download, verification, and unpacking
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
#               $? simulated preparation failure
install::prepare() {
    printf 'PREPARE\n' >&3
    return "${PREPARE_STATUS:-0}"
}

# @type:        Sink
# @description: Simulates copying the prepared release into the system
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
install::to_system() {
    printf 'INSTALL\n' >&3
}

# @type:        Orchestrator
# @description: Captures the installed uninstaller command and simulates its result
# @params:      args Command and arguments (array), without terminators
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 simulated removal success
#               $? simulated uninstaller failure
io::command::run_terminal() {
    printf 'TERMINAL' >&3
    printf ' <%s>' "$@" >&3
    printf '\n' >&3

    local rc="${UNINSTALL_STATUS:-0}"
    (( rc == 0 )) || return "$rc"
    [[ "${KEEP_INSTALL_PATHS:-0}" == 1 ]] || printf 'absent\n' >"$TEST_WORK_DIR/state"
}

# @type:        Orchestrator
# @description: Runs one isolated installer replacement scenario
# @stdin:       None
# @stdout:      None
# @exit_code:   $? installer orchestration status
test::runner::scenario() {
    printf '%s\n' "${EXISTING_STATE:-absent}" >"$TEST_WORK_DIR/state"
    install::orchestrator
}

# @type:        Orchestrator
# @description: Executes a scenario and verifies its exit status and clean stdout
# @params:      expected_status Expected status (num), without terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 assertions passed
#               1 status or output assertion failed
test::runner::run() {
    local expected_status="$1" status=0

    EXISTING_STATE="${EXISTING_STATE:-absent}" \
    PREPARE_STATUS="${PREPARE_STATUS:-0}" \
    UNINSTALL_STATUS="${UNINSTALL_STATUS:-0}" \
    KEEP_INSTALL_PATHS="${KEEP_INSTALL_PATHS:-0}" \
    CONFIRM_STATUS="${CONFIRM_STATUS:-0}" \
        bash "${BASH_SOURCE[0]}" --scenario \
        >"$TEST_WORK_DIR/stdout" \
        2>"$TEST_WORK_DIR/stderr" \
        3>"$TEST_WORK_DIR/events" || status=$?

    if [[ "$status" != "$expected_status" ]]; then
        cat "$TEST_WORK_DIR/events" "$TEST_WORK_DIR/stderr" >&2
        printf 'Expected status %s, got %s\n' "$expected_status" "$status" >&2
        return 1
    fi
    [[ ! -s "$TEST_WORK_DIR/stdout" ]]
}

# @type:        Orchestrator
# @description: Tests clean installation and replacement of an existing BSSS copy
# @stdin:       None
# @stdout:      result\n
# @exit_code:   0 all assertions passed
#               $? assertion or command failure
main() {
    if [[ "${1:-}" == --scenario ]]; then
        test::runner::scenario
        return
    fi

    export TEST_WORK_DIR
    TEST_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bsss-oneline-tests.XXXXXX")
    trap 'rm -rf "$TEST_WORK_DIR"' EXIT

    test::runner::run 0
    grep -Fx 'CONFIRM' "$TEST_WORK_DIR/events"
    grep -Fx 'PREPARE' "$TEST_WORK_DIR/events"
    grep -Fx 'INSTALL' "$TEST_WORK_DIR/events"
    test::assert::no_match '^TERMINAL' "$TEST_WORK_DIR/events"

    CONFIRM_STATUS=2 test::runner::run 2
    test::assert::no_match '^PREPARE$\|^TERMINAL\|^INSTALL$' "$TEST_WORK_DIR/events"

    EXISTING_STATE=valid test::runner::run 0
    test::assert::no_match '^CONFIRM$' "$TEST_WORK_DIR/events"
    grep -Fx 'PREPARE' "$TEST_WORK_DIR/events"
    grep -Fx 'TERMINAL <bash> </opt/bsss/main.sh> <-l> <en> <-u>' "$TEST_WORK_DIR/events"
    grep -Fx 'INSTALL' "$TEST_WORK_DIR/events"
    grep -F 'SUCCESS Installed BSSS was removed using its standard uninstaller' "$TEST_WORK_DIR/events"
    [[ $(grep -n '^PREPARE$' "$TEST_WORK_DIR/events" | cut -d: -f1) -lt $(grep -n '^TERMINAL' "$TEST_WORK_DIR/events" | cut -d: -f1) ]]
    [[ $(grep -n '^TERMINAL' "$TEST_WORK_DIR/events" | cut -d: -f1) -lt $(grep -n '^INSTALL$' "$TEST_WORK_DIR/events" | cut -d: -f1) ]]

    EXISTING_STATE=valid PREPARE_STATUS=23 test::runner::run 23
    test::assert::no_match '^TERMINAL\|^INSTALL$' "$TEST_WORK_DIR/events"

    EXISTING_STATE=valid UNINSTALL_STATUS=2 test::runner::run 2
    grep -F 'WARN Installed BSSS removal was cancelled' "$TEST_WORK_DIR/events"
    grep -F 'INFO To uninstall previously installed BSSS script run: sudo bsss -u' "$TEST_WORK_DIR/events"
    test::assert::no_match '^INSTALL$' "$TEST_WORK_DIR/events"

    EXISTING_STATE=valid UNINSTALL_STATUS=130 test::runner::run 130
    grep -F 'WARN Installed BSSS removal was cancelled' "$TEST_WORK_DIR/events"
    test::assert::no_match '^INSTALL$' "$TEST_WORK_DIR/events"

    EXISTING_STATE=valid UNINSTALL_STATUS=42 test::runner::run 42
    grep -F 'ERROR Standard BSSS removal failed [RC: 42]' "$TEST_WORK_DIR/events"
    test::assert::no_match '^INSTALL$' "$TEST_WORK_DIR/events"

    EXISTING_STATE=valid KEEP_INSTALL_PATHS=1 test::runner::run 1
    grep -F 'ERROR Standard removal completed, but BSSS installation paths remain' "$TEST_WORK_DIR/events"
    test::assert::no_match '^INSTALL$' "$TEST_WORK_DIR/events"

    EXISTING_STATE=invalid test::runner::run 1
    grep -F 'ERROR Script already installed in system or another script with same directory name installed.' "$TEST_WORK_DIR/events"
    test::assert::no_match '^PREPARE$\|^TERMINAL\|^INSTALL$' "$TEST_WORK_DIR/events"

    grep -Fq 'grep -Fq '\''# BSSS: Basic Server Security Setup'\''' "${PROJECT_ROOT}/oneline-runner.sh"
    grep -Fq 'grep -Fxq "$INSTALL_DIR" "$uninstall_file_path"' "${PROJECT_ROOT}/oneline-runner.sh"
    grep -Fq 'grep -Fxq "$SYMBOL_LINK_PATH" "$uninstall_file_path"' "${PROJECT_ROOT}/oneline-runner.sh"

    printf 'All one-line installer tests passed.\n'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
