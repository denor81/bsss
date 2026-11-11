#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../user-modify.sh"
trap - EXIT
source "${PROJECT_ROOT}/lib/i18n/en/common.sh"
source "${PROJECT_ROOT}/modules/.tests/helpers/assertions.sh"

# @type:        Sink
# @description: Captures messages without invoking the real logger
# @params:      message Log message (string), without terminator
# @stdin:       None
# @stdout:      None; message\n on FD3
# @exit_code:   0 success
log_info() {
    printf 'INFO %s\n' "$1" >&3
}

# @type:        Sink
# @description: Captures menu entries without invoking the real logger
# @params:      message Menu entry (string), without terminator
# @stdin:       None
# @stdout:      None; message\n on FD3
# @exit_code:   0 success
log_info_simple_tab() {
    printf 'MENU %s\n' "$1" >&3
}

# @type:        Sink
# @description: Suppresses the test password instead of logging it
# @params:      message Secret message (string), without terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 success
log_info_no_log() {
    :
}

# @type:        Source
# @description: Simulates a sudo mode selection or cancellation
# @params:      args Prompt arguments (array), without terminators
# @stdin:       None
# @stdout:      selection\0
# @exit_code:   0 selected
#               2 cancelled
io::ask_value() {
    [[ "$SELECT_ID" != 0 ]] || return 2
    printf '%s\0' "$SELECT_ID"
}

# @type:        Validator
# @description: Records confirmation and simulates acceptance or refusal
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
# @description: Records password generation without generating a real secret
# @stdin:       None
# @stdout:      password\n; event\n on FD3
# @exit_code:   0 success
user::pass::generate() {
    printf 'GENERATE\n' >&3
    printf 'test-secret\n'
}

# @type:        Sink
# @description: Records user creation without modifying the system
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
user::create::execute() {
    printf 'CREATE\n' >&3
}

# @type:        Sink
# @description: Verifies password input without invoking chpasswd
# @stdin:       username:password\0
# @stdout:      None; event\n on FD3
# @exit_code:   0 expected credentials received
#               1 unexpected input
user::pass::set() {
    local credentials
    IFS= read -r -d '' credentials
    [[ "$credentials" == "$BSSS_USER_NAME:test-secret" ]]
    printf 'PASSWORD\n' >&3
}

# @type:        Sink
# @description: Records the selected sudo mode without writing sudoers
# @params:      mode PASSWD or NOPASSWD (string), without terminator
# @stdin:       None
# @stdout:      None; event\n on FD3
# @exit_code:   0 success
user::sudoers::create_file() {
    printf 'SUDOERS %s\n' "$1" >&3
}

# @type:        Sink
# @description: Suppresses unrelated removal reminders
# @stdin:       None
# @stdout:      None
# @exit_code:   0 success
user::log::del_reminder() {
    :
}

# @type:        Orchestrator
# @description: Runs a creation scenario in a fresh shell with strict mode enabled
# @params:      status Expected exit status (num), without terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 expected status and clean output
#               1 assertion failed
test::user::run() {
    local status=0
    bash "${BASH_SOURCE[0]}" --scenario >"$TEST_WORK_DIR/stdout" 2>"$TEST_WORK_DIR/stderr" 3>"$TEST_WORK_DIR/events" || status=$?
    [[ "$status" == "$1" ]]
    [[ ! -s "$TEST_WORK_DIR/stdout" && ! -s "$TEST_WORK_DIR/stderr" ]]
}

# @type:        Orchestrator
# @description: Tests sudo explanations, confirmation ordering, and cancellation
# @params:      scenario Optional --scenario flag (string), without terminator
# @stdin:       None
# @stdout:      result\n
# @exit_code:   0 all assertions passed
#               $? assertion or command failure
main() {
    if [[ "${1:-}" == --scenario ]]; then
        user::sudo::menu
        return
    fi

    export TEST_WORK_DIR SELECT_ID CONFIRM_STATUS
    TEST_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bsss-user-create.XXXXXX")
    trap 'rm -rf "$TEST_WORK_DIR"' EXIT

    for SELECT_ID in 1 2; do
        CONFIRM_STATUS=0
        test::user::run 0
        grep -Fx "CONFIRM Create user $BSSS_USER_NAME?" "$TEST_WORK_DIR/events"
        [[ $(grep -n '^CONFIRM ' "$TEST_WORK_DIR/events" | cut -d: -f1) -lt $(grep -n '^GENERATE$' "$TEST_WORK_DIR/events" | cut -d: -f1) ]]
        if [[ "$SELECT_ID" == 1 ]]; then
            grep -F 'cached for 30 minutes across all' "$TEST_WORK_DIR/events"
            grep -Fx 'SUDOERS PASSWD' "$TEST_WORK_DIR/events"
        else
            grep -F 'Sudo will not ask for a password.' "$TEST_WORK_DIR/events"
            grep -Fx 'SUDOERS NOPASSWD' "$TEST_WORK_DIR/events"
        fi
        [[ $(grep -n '^INFO Sudo ' "$TEST_WORK_DIR/events" | cut -d: -f1) -lt $(grep -n '^CONFIRM ' "$TEST_WORK_DIR/events" | cut -d: -f1) ]]
        grep -Fx 'CREATE' "$TEST_WORK_DIR/events"
        grep -Fx 'PASSWORD' "$TEST_WORK_DIR/events"
        test::assert::no_match 'test-secret' "$TEST_WORK_DIR/events"

        CONFIRM_STATUS=2
        test::user::run 2
        grep -Fx "CONFIRM Create user $BSSS_USER_NAME?" "$TEST_WORK_DIR/events"
        test::assert::no_match '^GENERATE\|^CREATE\|^PASSWORD\|^SUDOERS' "$TEST_WORK_DIR/events"
    done

    SELECT_ID=0
    test::user::run 2
    test::assert::no_match '^CONFIRM\|^GENERATE\|^CREATE\|^PASSWORD\|^SUDOERS' "$TEST_WORK_DIR/events"
    printf 'User creation tests passed\n'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
