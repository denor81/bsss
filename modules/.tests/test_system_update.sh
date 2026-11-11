#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../system-update.sh"
trap - EXIT
source "${PROJECT_ROOT}/lib/i18n/en/common.sh"

# @type:        Sink
# @description: Captures informational messages without invoking the real logger
# @params:      message Log message (string), without terminator
# @stdin:       None
# @stdout:      None; message\n on FD3
# @exit_code:   0 success
log_info() {
    printf 'INFO %s\n' "$1" >&3
}

# @type:        Sink
# @description: Captures errors without invoking the real logger
# @params:      message Log message (string), without terminator
# @stdin:       None
# @stdout:      None; message\n on FD3
# @exit_code:   0 success
log_error() {
    printf 'ERROR %s\n' "$1" >&3
}

# @type:        Sink
# @description: Captures bold headings without invoking the real logger
# @params:      message Heading (string), without terminator
# @stdin:       None
# @stdout:      None; heading\n on FD3
# @exit_code:   0 success
log_bold_info() {
    printf 'BOLD %s\n' "$1" >&3
}

# @type:        Sink
# @description: Captures SSH configuration warnings
# @params:      message Configuration line (string), without terminator
# @stdin:       None
# @stdout:      None; message\n on FD3
# @exit_code:   0 success
log_warn_simple_tab() {
    printf 'WARN_TAB %s\n' "$1" >&3
}

# @type:        Sink
# @description: Captures informational configuration lines
# @params:      message Configuration line (string), without terminator
# @stdin:       None
# @stdout:      None; message\n on FD3
# @exit_code:   0 success
log_info_simple_tab() {
    printf 'INFO_TAB %s\n' "$1" >&3
}

# @type:        Source
# @description: Supplies SSH configuration without reading the host configuration
# @params:      option Expected -T argument (string), without terminator
# @stdin:       None
# @stdout:      configuration_line\n repeated
# @exit_code:   0 success
sshd() {
    [[ "$1" == -T ]]
    printf '%s\n' "$TEST_SSH_CONFIG"
}

# @type:        Validator
# @description: Records the confirmation and simulates acceptance or cancellation
# @params:      question Confirmation text (string), without terminator
# @stdin:       None
# @stdout:      None; question\n on FD3
# @exit_code:   0 accepted
#               2 cancelled
io::confirm_action() {
    printf 'CONFIRM %s\n' "$1" >&3
    return "${CONFIRM_STATUS:-0}"
}

# @type:        Source
# @description: Simulates an update submenu selection
# @params:      args Prompt arguments (array), without terminators
# @stdin:       None
# @stdout:      selection\0
# @exit_code:   0 selected
#               2 back selected
io::ask_value() {
    [[ "$SELECT_ID" != 0 ]] || return 2
    printf '%s\0' "$SELECT_ID"
}

# @type:        Orchestrator
# @description: Executes only the generated shell command using the mock apt-get
# @params:      args Command arguments (array), without terminators
# @stdin:       None
# @stdout:      Command-defined output
# @exit_code:   $? command status
io::command::run_terminal() {
    [[ "$#" == 3 && "$1" == bash && "$2" == -c ]]
    "$@"
}

# @type:        Source
# @description: Simulates byte-accurate root filesystem snapshots
# @params:      args Expected df arguments (array), without terminators
# @stdin:       None
# @stdout:      header\nsizes\n
# @exit_code:   0 success
#               1 simulated snapshot failure
df() {
    [[ "$*" == '-B1 --output=size,used,avail /' ]]
    local state
    state=$(cat "$TEST_WORK_DIR/state")
    [[ "${FAIL_AT:-}" != df || "${FAIL_STAGE:-before}" != "$state" ]] || return 1
    printf 'Size Used Avail\n'
    case "$state" in
        before) printf '21474836480 12884901888 8589934592\n' ;;
        updated) printf '21474836480 13421772800 8053063680\n' ;;
        cleaned) printf '21474836480 11811160064 9663676416\n' ;;
    esac
}

# @type:        Sink
# @description: Simulates package operations without modifying system packages
# @params:      args apt-get arguments (array), without terminators
# @stdin:       None
# @stdout:      None; command\n on FD3
# @exit_code:   0 success
#               42 simulated package failure
apt-get() {
    printf 'APT %s\n' "$*" >&3
    [[ "${FAIL_AT:-}" != "$1" ]] || return 42
    case "$1" in
        upgrade) printf 'updated\n' >"$TEST_WORK_DIR/state" ;;
        clean) printf 'cleaned\n' >"$TEST_WORK_DIR/state" ;;
    esac
}
export -f apt-get

# @type:        Orchestrator
# @description: Runs an isolated scenario with strict mode enabled
# @params:      scenario Test case (string), without terminator
# @stdin:       None
# @stdout:      None; captured events on FD3
# @exit_code:   $? scenario status
test::update::scenario() {
    case "$1" in
        only) sys::update::orchestrator ;;
        cleanup) sys::update::orchestrator cleanup ;;
        auto) sys::update::get_command auto | sys::update::execute ;;
        menu) sys::update::menu ;;
    esac
}

# @type:        Orchestrator
# @description: Verifies a scenario's status while capturing all output
# @params:      scenario Test case (string), without terminator
#               status Expected exit status (num), without terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 assertions passed
#               1 assertion failed
test::update::run() {
    printf 'before\n' >"$TEST_WORK_DIR/state"
    local status=0
    bash "${BASH_SOURCE[0]}" --scenario "$1" >"$TEST_WORK_DIR/stdout" 3>"$TEST_WORK_DIR/events" || status=$?
    [[ "$status" == "$2" ]]
    [[ ! -s "$TEST_WORK_DIR/stdout" ]]
}

# @type:        Orchestrator
# @description: Tests update selection, cleanup, disk deltas, failures, and formatting
# @stdin:       None
# @stdout:      result\n
# @exit_code:   0 all assertions passed
#               $? assertion or command failure
main() {
    if [[ "${1:-}" == --scenario ]]; then
        test::update::scenario "$2"
        return
    fi

    export TEST_WORK_DIR
    TEST_WORK_DIR=$(mktemp -d /tmp/opencode/bsss-update-tests.XXXXXX)
    trap 'rm -rf "$TEST_WORK_DIR"' EXIT

    test::update::run only 0
    grep -Fx 'CONFIRM Update system packages? [apt-get update && apt-get upgrade --with-new-pkgs -y]' "$TEST_WORK_DIR/events"
    [[ $(grep -c '^APT ' "$TEST_WORK_DIR/events") == 2 ]]
    grep -F 'available space decreased by 512.0MiB.' "$TEST_WORK_DIR/events"
    ! grep -q 'cleanup' "$TEST_WORK_DIR/events"

    test::update::run cleanup 0
    grep -F '[apt-get update && apt-get upgrade --with-new-pkgs -y && apt-get autoremove -y && apt-get clean]' "$TEST_WORK_DIR/events"
    [[ $(grep -c '^APT ' "$TEST_WORK_DIR/events") == 4 ]]
    [[ $(grep -c '(/): total' "$TEST_WORK_DIR/events") == 3 ]]
    grep -F 'After automatic cleanup (/): total 20.0GiB, used 11.0GiB, available 9.0GiB.' "$TEST_WORK_DIR/events"
    grep -F 'Cleanup after the update freed 1.5GiB.' "$TEST_WORK_DIR/events"
    grep -F 'Overall since start: available space increased by 1.0GiB.' "$TEST_WORK_DIR/events"
    [[ $(grep -n 'After update' "$TEST_WORK_DIR/events" | cut -d: -f1) -lt $(grep -n 'APT autoremove' "$TEST_WORK_DIR/events" | cut -d: -f1) ]]

    test::update::run auto 0
    [[ $(grep -c '^APT ' "$TEST_WORK_DIR/events") == 2 ]]
    grep -F -- '--force-confold upgrade --with-new-pkgs -y' "$TEST_WORK_DIR/events"
    ! grep -q 'CONFIRM\|autoremove' "$TEST_WORK_DIR/events"

    CONFIRM_STATUS=2 test::update::run cleanup 2
    ! grep -q '^APT \|^INFO ' "$TEST_WORK_DIR/events"

    local operation
    for operation in update upgrade autoremove clean; do
        FAIL_AT="$operation" test::update::run cleanup 1
        ! grep -q 'After automatic cleanup' "$TEST_WORK_DIR/events"
        if [[ "$operation" == update || "$operation" == upgrade ]]; then
            ! grep -q 'After update\|APT autoremove\|APT clean' "$TEST_WORK_DIR/events"
        else
            grep -q 'ERROR Error removing unused packages' "$TEST_WORK_DIR/events"
        fi
    done

    FAIL_AT=df test::update::run cleanup 1
    ! grep -q '^APT ' "$TEST_WORK_DIR/events"
    FAIL_AT=df FAIL_STAGE=updated test::update::run cleanup 1
    ! grep -q 'After update\|APT autoremove\|APT clean' "$TEST_WORK_DIR/events"

    SELECT_ID=0 test::update::run menu 2
    ! grep -q '^APT \|^CONFIRM ' "$TEST_WORK_DIR/events"
    SELECT_ID=1 test::update::run menu 0
    grep -q '^APT clean$' "$TEST_WORK_DIR/events"
    SELECT_ID=2 test::update::run menu 0
    ! grep -q '^APT autoremove\|^APT clean' "$TEST_WORK_DIR/events"

    [[ $(sys::update::format_size 0) == 0.0B ]]
    [[ $(sys::update::format_size 1024) == 1.0KiB ]]
    [[ $(sys::update::format_size 1319) == 1.3KiB ]]
    [[ $(sys::update::format_size 1099511627776) == 1.0TiB ]]
    sys::update::log_delta 100 100 total 3>"$TEST_WORK_DIR/events"
    grep -q 'available space is unchanged' "$TEST_WORK_DIR/events"
    sys::update::log_delta 1024 0 cleanup 3>"$TEST_WORK_DIR/events"
    grep -q 'During cleanup, available space decreased by 1.0KiB.' "$TEST_WORK_DIR/events"
    sys::update::log_delta 100 100 cleanup 3>"$TEST_WORK_DIR/events"
    grep -q 'During cleanup, available space is unchanged' "$TEST_WORK_DIR/events"

    TEST_SSH_CONFIG=$'port 22\npasswordauthentication yes\npermitrootlogin yes'
    common::log::current_config '^(port|passwordauthentication|permitrootlogin) ' 3>"$TEST_WORK_DIR/events"
    grep -Fxq 'BOLD Current SSH configuration [sshd -T]:' "$TEST_WORK_DIR/events"
    [[ $(grep -c '^WARN_TAB ' "$TEST_WORK_DIR/events") == 3 ]]
    TEST_SSH_CONFIG=$'port 2222\npasswordauthentication no\npermitrootlogin no'
    common::log::current_config '^(port|passwordauthentication|permitrootlogin) ' 3>"$TEST_WORK_DIR/events"
    grep -Fxq 'BOLD Current SSH configuration [sshd -T]:' "$TEST_WORK_DIR/events"
    [[ $(grep -c '^INFO_TAB ' "$TEST_WORK_DIR/events") == 3 ]]
    ! grep -q '^WARN_TAB ' "$TEST_WORK_DIR/events"

    printf 'All system update tests passed.\n'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
