#!/usr/bin/env bash
# @name: ufw-enable
# @description: Test UFW enable scenario
# @expected: Exit code 0, process lifecycle validated, UFW enabled, BSSS UFW rules created
# @timeout: 30

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

# Source project modules for setup/cleanup functions
source "${PROJECT_ROOT}/modules/common-helpers.sh"

# Test metadata
TEST_NAME="ufw-enable"
TEST_DESCRIPTION="UFW enable scenario"

# @type:        Orchestrator
# @description: Set up initial state for UFW enable test
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
test::setup() {
    test::log_info "Setting up UFW enable test..."
    
    # Ensure UFW is disabled
    test::log_info "Disabling UFW..."
    ufw::force_disable
    
    # Remove any existing BSSS UFW rules
    test::log_info "Cleaning UFW state..."
    ufw::delete_all_bsss_rules
    
    test::log_validation "Setup complete"
    return 0
}

# @type:        Orchestrator
# @description: Clean up system state after UFW enable test
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
test::cleanup() {
    test::log_info "Cleaning up UFW enable test..."
    
    # Disable UFW
    test::log_info "Disabling UFW..."
    ufw::force_disable
    
    # Remove any BSSS UFW rules
    test::log_info "Cleaning UFW state..."
    ufw::delete_all_bsss_rules
    
    test::log_validation "Cleanup complete"
    return 0
}

# @type:        Orchestrator
# @description: Validate UFW enable test results
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - validation passed
#               1 - validation failed
test::custom_validate() {
    local log_file="$1"
    
    test::log_info "Validating UFW enable test results..."
    
    # Check if UFW is enabled
    test::log_info "Checking UFW enabled..."
    if ! ufw::is_active; then
        test::log_fail "Custom validation" "UFW is not enabled"
        return 1
    fi
    test::log_validation "UFW is enabled"
    
    # Check if BSSS UFW rules were created
    test::log_info "Checking BSSS UFW rules created..."
    local ufw_rule_count
    ufw_rule_count=$(ufw::get_all_bsss_rules | tr -d '\0' | wc -l)
    if [[ "$ufw_rule_count" -eq 0 ]]; then
        test::log_fail "Custom validation" "BSSS UFW rules not created"
        return 1
    fi
    test::log_validation "BSSS UFW rules created ($ufw_rule_count rule(s))"
    
    test::log_validation "Custom validation passed"
    return 0
}

# @type:        Orchestrator
# @description: Run UFW enable test scenario
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
    # CRITICAL: TEST_MODULE must be set to specify which module to test
    export TEST_MODE="true"
    export LOG_MODE="both"
    export TEST_SCENARIO="$TEST_NAME"
    export TEST_MODULE="05-ufw-modify.sh"
    
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
    
    test::log_info "Running UFW enable test"
    test::log_info "Log file: $log_file"
    
    # Run BSSS in test mode and capture exit code
    # CRITICAL: The exit code must be captured and validated
    # BSSS exit codes: 0 = success, 2 = cancellation, 3 = rollback
    sudo TEST_SCENARIO="$TEST_SCENARIO" TEST_MODULE="$TEST_MODULE" bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    # Validate process lifecycle
    test::log_info "Validating process lifecycle..."
    if ! test::validate_lifecycle "$log_file"; then
        test::cleanup
        return 1
    fi
    
    # Validate exit code (expecting 0 for success)
    test::log_info "Validating exit code..."
    if ! test::validate_exit_code "$exit_code" "0"; then
        test::cleanup
        return 1
    fi
    
    # Custom validation
    test::log_info "Running custom validation..."
    if ! test::custom_validate "$log_file"; then
        test::cleanup
        return 1
    fi
    
    # Clean up
    test::cleanup
    
    return 0
}
