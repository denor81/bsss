#!/usr/bin/env bash
# @description: Test execution engine for BSSS testing framework

# @type:        Orchestrator
# @description: Discover all test scenarios in tests/scenarios/
# @stdin:       none
# @stdout:      List of test scenario files (NUL-separated)
# @exit_code:   0 - success
test::discover_scenarios() {
    local scenarios_dir="${TESTS_DIR:-./tests}/scenarios"
    
    if [[ ! -d "$scenarios_dir" ]]; then
        echo "Error: Scenarios directory not found: $scenarios_dir" >&2
        return 1
    fi
    
    # Find all .sh files in scenarios directory
    # Output NUL-separated for safe handling
    find "$scenarios_dir" -type f -name "*.sh" -print0 | sort -z
}

# @type:        Orchestrator
# @description: Check if a test file is valid (has test::run function)
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - valid
#               1 - invalid
test::is_valid_scenario() {
    local test_file="$1"
    
    # Check if file exists
    [[ -f "$test_file" ]] || return 1
    
    # Check if file has test::run function
    if grep -q "^test::run()" "$test_file"; then
        return 0
    else
        return 1
    fi
}

# @type:        Orchestrator
# @description: Extract test metadata from file comments
# @stdin:       none
# @stdout:      Metadata value
# @exit_code:   0 - found
#               1 - not found
test::get_metadata() {
    local test_file="$1"
    local metadata_key="$2"
    
    # Extract metadata from comments like: # @name: test-name
    grep "^# @${metadata_key}:" "$test_file" | sed "s/^# @${metadata_key}: //"
}

# @type:        Orchestrator
# @description: Run a single test scenario with timeout
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - test passed
#               1 - test failed
#               2 - test cancelled
#               124 - test timeout
test::run_scenario() {
    local test_file="$1"
    local timeout="${2:-${TEST_TIMEOUT:-30}}"
    
    # Check if file is valid
    if ! test::is_valid_scenario "$test_file"; then
        test::log_fail "$(basename "$test_file")" "Invalid test scenario (missing test::run function)"
        return 1
    fi
    
    # Run test with timeout, preserving TEST_MODULE
    # Source the test file in the subshell to avoid variable redefinition issues
    timeout "$timeout" bash -c "
        export TEST_MODULE=\"${TEST_MODULE:-}\"
        source \"$test_file\" || exit 1
        test::run
    "
    local exit_code=$?
    
    case "$exit_code" in
        0)  return 0 ;;
        1)  return 1 ;;
        2)  return 2 ;;
        124) 
            test::log_fail "$(basename "$test_file")" "Test timeout after ${timeout}s"
            return 124
            ;;
        *)
            test::log_fail "$(basename "$test_file")" "Unexpected exit code: $exit_code"
            return 1
            ;;
    esac
}

# @type:        Orchestrator
# @description: Calculate test duration
# @stdin:       none
# @stdout:      Duration in seconds
# @exit_code:   0 - success
test::calculate_duration() {
    local start_time="$1"
    local end_time="$2"
    
    echo "$end_time - $start_time" | bc
}
