#!/usr/bin/env bash
# @name: test-name
# @description: Brief description of what this test validates
# @expected: Expected outcome (e.g., "Exit code 0, process lifecycle validated")
# @depends: [optional] Other tests this depends on (comma-separated)
# @timeout: [optional] Max duration in seconds (default: 30)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Set module name for logging
readonly CURRENT_MODULE_NAME="$(basename "$0")"

# Source test libraries
source "${SCRIPT_DIR}/../lib/test-logging.sh"
source "${SCRIPT_DIR}/../lib/test-parser.sh"

# Source project libraries
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/vars.conf"

# Test metadata
TEST_NAME="test-name"
TEST_DESCRIPTION="Brief description of what this test validates"

# @type:        Orchestrator
# @description: Set up initial state before running test
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
test::setup() {
    test::log_info "Setting up test environment..."
    
    # Add any setup logic here:
    # - Clean system state
    # - Set environment variables
    # - Create test data
    # - etc.
    
    test::log_validation "Setup complete"
    return 0
}

# @type:        Orchestrator
# @description: Clean up system state after test
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
test::cleanup() {
    test::log_info "Cleaning up test environment..."
    
    # Add any cleanup logic here:
    # - Remove test data
    # - Reset system state
    # - Delete temporary files
    # - etc.
    
    test::log_validation "Cleanup complete"
    return 0
}

# @type:        Orchestrator
# @description: Custom validation logic (optional)
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - validation passed
#               1 - validation failed
test::custom_validate() {
    local log_file="$1"
    
    # Add custom validation logic here:
    # - Check specific log messages
    # - Verify system state
    # - Validate file contents
    # - etc.
    
    test::log_validation "Custom validation passed"
    return 0
}

# @type:        Orchestrator
# @description: Run the test scenario
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - test passed
#               1 - test failed
#               2 - test cancelled
test::run() {
    local log_file
    local exit_code
    
    # Set up test environment
    test::setup || return 1
    
    # Set test mode environment variables
    # CRITICAL: TEST_MODE must be set to enable non-interactive mode
    # CRITICAL: LOG_MODE must be "both" or "file" to enable file logging
    export TEST_MODE="true"
    export LOG_MODE="both"
    export TEST_SCENARIO="$TEST_NAME"
    
    # Generate log file path
    # Use the same naming convention as local-runner.sh: bsss-${scenario_name}-${timestamp}.log
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local scenario_name="${TEST_SCENARIO:-default}"
    log_file="${TEST_LOG_DIR}/bsss-${scenario_name}-${timestamp}.log"
    export LOG_FILE="$log_file"
    
    # Ensure log directory exists
    local log_dir
    log_dir="$(dirname "$log_file")"
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || {
            test::log_fail "Setup" "Failed to create log directory: $log_dir"
            test::cleanup
            return 1
        }
    fi
    
    test::log_info "Running BSSS in test mode"
    test::log_info "Log file: $log_file"
    
    # Run BSSS in test mode and capture exit code
    # CRITICAL: The exit code must be captured and validated
    # BSSS exit codes: 0 = success, 2 = cancellation, 3 = rollback
    sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    # Validate process lifecycle
    test::log_info "Validating process lifecycle..."
    if ! test::validate_lifecycle "$log_file"; then
        test::cleanup
        return 1
    fi
    
    # Validate exit code
    test::log_info "Validating exit code..."
    # Expected codes: 0 = success, 2 = cancellation, 3 = rollback
    if ! test::validate_exit_code "$exit_code" "0,2,3"; then
        test::cleanup
        return 1
    fi
    
    # Custom validation (optional)
    if declare -f test::custom_validate >/dev/null; then
        test::log_info "Running custom validation..."
        if ! test::custom_validate "$log_file"; then
            test::cleanup
            return 1
        fi
    fi
    
    # Clean up
    test::cleanup
    
    return 0
}
