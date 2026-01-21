#!/usr/bin/env bash
# @description: Test-specific logging utilities for BSSS testing framework

# Test result symbols
# Define only if not already defined (to avoid redefining readonly variables)
[[ -z "${TEST_OK:-}" ]] && readonly TEST_OK="[OK]"
[[ -z "${TEST_FAIL:-}" ]] && readonly TEST_FAIL="[FAIL]"
[[ -z "${TEST_INFO:-}" ]] && readonly TEST_INFO="[TEST]"
[[ -z "${TEST_WARN:-}" ]] && readonly TEST_WARN="[WARN]"

# @type:        Source
# @description: Log test start message
# @stdin:       none
# @stdout:      Test start message to stderr
# @exit_code:   0 - success
test::log_start() {
    local test_name="$1"
    echo -e "${TEST_INFO} Running ${test_name}..." >&2
}

# @type:        Source
# @description: Log test pass message
# @stdin:       none
# @stdout:      Test pass message to stderr
# @exit_code:   0 - success
test::log_pass() {
    local test_name="$1"
    local duration="${2:-0.0}"
    echo -e "${TEST_OK} ${test_name} passed (${duration}s)" >&2
}

# @type:        Source
# @description: Log test fail message
# @stdin:       none
# @stdout:      Test fail message to stderr
# @exit_code:   0 - success
test::log_fail() {
    local test_name="$1"
    local error="$2"
    echo -e "${TEST_FAIL} ${test_name} failed - ${error}" >&2
}

# @type:        Source
# @description: Log test info message
# @stdin:       none
# @stdout:      Test info message to stderr
# @exit_code:   0 - success
test::log_info() {
    local message="$1"
    echo -e "${TEST_INFO} ${message}" >&2
}

# @type:        Source
# @description: Log test validation message
# @stdin:       none
# @stdout:      Test validation message to stderr
# @exit_code:   0 - success
test::log_validation() {
    local message="$1"
    echo -e "${TEST_OK} ${message}" >&2
}

# @type:        Source
# @description: Log test warning message
# @stdin:       none
# @stdout:      Test warning message to stderr
# @exit_code:   0 - success
test::log_warn() {
    local message="$1"
    echo -e "${TEST_WARN} ${message}" >&2
}
