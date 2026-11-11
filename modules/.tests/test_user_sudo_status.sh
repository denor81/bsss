#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
readonly PROJECT_ROOT
source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/i18n/en/common.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"
source "${PROJECT_ROOT}/modules/.tests/helpers/assertions.sh"

readonly FIXTURES_DIR="${PROJECT_ROOT}/modules/.tests/fixtures/sudo"

# @type:        Source
# @description: Supplies a sudo policy without reading host sudoers or authenticating
# @params:      args Expected listing arguments (array), without terminators
# @stdin:       None
# @stdout:      sudo listing (line\n, 0..N); event\n on FD3
# @exit_code:   0 listing obtained
#               1 unexpected invocation
#               23 simulated policy failure
sudo() {
    printf 'SUDO %s\n' "$*" >&3
    if [[ "$*" == "-n -ll -U $BSSS_USER_NAME" ]]; then
        [[ "$LC_ALL" == C ]] || return 1
        cat "$SUDO_FIXTURE"
        if [[ "${SUDO_STATUS:-0}" != 0 ]]; then
            printf 'sudo: simulated policy failure\n' >&2
            return "$SUDO_STATUS"
        fi
    elif [[ "$*" == '-l -U alice' ]]; then
        printf '    (ALL) NOPASSWD: ALL\n'
    else
        return 1
    fi
}

# @type:        Source
# @description: Supplies users without reading host accounts
# @stdin:       None
# @stdout:      username:password:uid:gid:gecos:home:shell\0 repeated
# @exit_code:   0 success
user::list::get() {
    printf '%s\0' 'root:x:0:0::/root:/bin/bash' "$BSSS_USER_NAME:x:1000:1000::/home/$BSSS_USER_NAME:/bin/bash" 'alice:x:1001:1001::/home/alice:/bin/bash'
}

# @type:        Source
# @description: Supplies the session owner without querying the terminal
# @stdin:       None
# @stdout:      username\n
# @exit_code:   0 success
logname() {
    printf '%s\n' "$BSSS_USER_NAME"
}

# @type:        Source
# @description: Supplies an authentication method without reading the journal
# @stdin:       None
# @stdout:      method\0
# @exit_code:   0 success
sys::user::get_auth_method() {
    printf 'key\0'
}

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
# @description: Captures user rows without invoking the real logger
# @params:      message User information (string), without terminator
# @stdin:       None
# @stdout:      None; message\n on FD3
# @exit_code:   0 success
log_info_simple_tab() {
    printf 'USER %s\n' "$1" >&3
}

# @type:        Validator
# @description: Checks the parsed status including its NUL terminator
# @params:      mode Expected sudo mode (string), without terminator
#               cache Expected cache value (string), without terminator
# @stdin:       sudo listing (line\n, 0..N)
# @stdout:      None
# @exit_code:   0 expected status
#               $? parser or comparison failure
test::sudo::check() {
    user::sudo::parse_status >"$TEST_WORK_DIR/status"
    printf 'sudo:%s|sudocache:%s\0' "$1" "$2" | cmp - "$TEST_WORK_DIR/status"
}

# @type:        Validator
# @description: Requires unsupported input to fail without emitting a status
# @stdin:       unsupported listing (line\n, 0..N)
# @stdout:      None
# @exit_code:   0 input rejected
#               1 unsupported input accepted
test::sudo::reject() {
    if user::sudo::parse_status >"$TEST_WORK_DIR/status"; then
        return 1
    fi
    [[ ! -s "$TEST_WORK_DIR/status" ]]
}

# @type:        Orchestrator
# @description: Runs the real information block in a fresh strict-mode shell
# @params:      status Expected exit status (num), without terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 expected status and clean stdout
#               1 assertion failed
test::sudo::run() {
    local status=0
    bash "${BASH_SOURCE[0]}" --scenario >"$TEST_WORK_DIR/stdout" 2>"$TEST_WORK_DIR/stderr" 3>"$TEST_WORK_DIR/events" || status=$?
    [[ "$status" == "$1" ]]
    [[ ! -s "$TEST_WORK_DIR/stdout" ]]
}

# @type:        Orchestrator
# @description: Tests sudo timeout parsing, contextual policies, user rows, and failures
# @params:      scenario Optional --scenario flag (string), without terminator
# @stdin:       None
# @stdout:      result\n
# @exit_code:   0 all assertions passed
#               $? assertion or command failure
main() {
    if [[ "${1:-}" == --scenario ]]; then
        user::info::block
        printf 'AFTER\n' >&3
        return
    fi

    export TEST_WORK_DIR SUDO_FIXTURE SUDO_STATUS
    TEST_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bsss-user-sudo.XXXXXX")
    trap 'rm -rf "$TEST_WORK_DIR"' EXIT

    test::sudo::check pass 30m <"$FIXTURES_DIR/pass.txt"
    test::sudo::check nopass n/a <"$FIXTURES_DIR/nopass.txt"
    test::sudo::check nosudo n/a <"$FIXTURES_DIR/nosudo.txt"
    test::sudo::check pass mixed <"$FIXTURES_DIR/scoped.txt"

    local timeout expected
    while read -r timeout expected; do
        sed "s/timestamp_timeout=30/timestamp_timeout=$timeout/" "$FIXTURES_DIR/pass.txt" | test::sudo::check pass "$expected"
    done <<'EOF'
0 no
0.0 no
-0 no
-1 unlimited
-2.5 unlimited
2.5 2.5m
.5 0.5m
+30 30m
30.00 30m
"30" 30m
EOF

    sed '/timestamp_timeout=30/d' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass default
    sed '1,/^$/d' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass default
    sed 's/timestamp_timeout=30/!timestamp_timeout/' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass no
    sed 's/timestamp_timeout=30/timestamp_timeout = 5, timestamp_timeout = 30/' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass 30m
    sed 's/timestamp_timeout=30/timestamp_timeout=30, timestamp_timeout=0/' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass no
    sed 's/timestamp_type=global/timestamp_type=tty/' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass 30m
    sed 's/timestamp_timeout=30/env_keep += "foo, timestamp_timeout=0, authenticate"/' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass default
    sed 's/timestamp_timeout=30/env_keep += "foo \\"bar\\", timestamp_timeout=0"/' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass default
    sed 's/        ALL/        \/bin\/echo timestamp_timeout=0, NOPASSWD: ALL/' "$FIXTURES_DIR/pass.txt" | test::sudo::check pass 30m
    sed 's/!authenticate/!authenticate,\n        log_output/' "$FIXTURES_DIR/nopass.txt" | test::sudo::check nopass n/a
    sed 's/!authenticate/!authenticate\n    Timeout: 60/' "$FIXTURES_DIR/nopass.txt" | test::sudo::check nopass n/a
    sed 's/authenticate/!authenticate/' "$FIXTURES_DIR/pass.txt" | test::sudo::check nopass n/a
    sed '/Options: authenticate/d; s/env_reset/!authenticate, env_reset/' "$FIXTURES_DIR/pass.txt" | test::sudo::check nopass n/a
    sed 's/!authenticate/authenticate/' "$FIXTURES_DIR/nopass.txt" | test::sudo::check pass default
    sed 's/timestamp_timeout=0/timestamp_timeout=30/; s/timestamp_timeout=2.5/timestamp_timeout=30/' "$FIXTURES_DIR/scoped.txt" | test::sudo::check pass 30m
    sed 's/timestamp_timeout=0/timestamp_timeout=0, timestamp_timeout=30/; s/timestamp_timeout=2.5/timestamp_timeout=30/' "$FIXTURES_DIR/scoped.txt" | test::sudo::check pass 30m
    sed 's/timestamp_timeout=0/log_output/; s/timestamp_timeout=2.5/log_input/' "$FIXTURES_DIR/scoped.txt" | test::sudo::check pass 30m
    sed 's/timestamp_timeout=0/!authenticate/; s/timestamp_timeout=2.5/log_input/' "$FIXTURES_DIR/scoped.txt" | test::sudo::check pass mixed

    test::sudo::reject </dev/null
    printf 'unrecognized output\n' | test::sudo::reject
    sed 's/timestamp_timeout=30/timestamp_timeout=broken/' "$FIXTURES_DIR/pass.txt" | test::sudo::reject

    SUDO_STATUS=0
    SUDO_FIXTURE="$FIXTURES_DIR/pass.txt"
    test::sudo::run 0
    grep -Fx "USER 2. $BSSS_USER_NAME|id:1000<<<Session owner|auth:key|sudo:pass|sudocache:30m" "$TEST_WORK_DIR/events"
    [[ $(grep -c "^SUDO -n -ll -U $BSSS_USER_NAME$" "$TEST_WORK_DIR/events") == 1 ]]
    grep -Fx 'USER 1. root|id:0|sudo:superuser' "$TEST_WORK_DIR/events"
    grep -Fx 'USER 3. alice|id:1001|sudo:nopass' "$TEST_WORK_DIR/events"
    [[ $(grep -c '^USER .*sudocache:' "$TEST_WORK_DIR/events") == 1 ]]
    [[ ! -s "$TEST_WORK_DIR/stderr" ]]

    for SUDO_FIXTURE in "$FIXTURES_DIR/nopass.txt" "$FIXTURES_DIR/nosudo.txt"; do
        test::sudo::run 0
        grep -F 'sudocache:n/a' "$TEST_WORK_DIR/events"
    done

    SUDO_FIXTURE="$FIXTURES_DIR/pass.txt"
    SUDO_STATUS=23
    test::sudo::run 23
    grep -Fx 'sudo: simulated policy failure' "$TEST_WORK_DIR/stderr"
    test::assert::no_match "^USER 2\.\|^AFTER$" "$TEST_WORK_DIR/events"
    SUDO_STATUS=1
    test::sudo::run 1
    test::assert::no_match "^USER 2\.\|^AFTER$" "$TEST_WORK_DIR/events"

    SUDO_STATUS=0
    SUDO_FIXTURE=/dev/null
    test::sudo::run 1
    test::assert::no_match "^USER 2\.\|^AFTER$" "$TEST_WORK_DIR/events"
    printf 'User sudo status tests passed\n'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
