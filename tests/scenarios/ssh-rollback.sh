#!/usr/bin/env bash
# @name: ssh-rollback
# @description: Test automatic rollback on connection timeout
# @expected: Exit code 3, process lifecycle validated, rollback executed, BSSS SSH and UFW rules removed
# @timeout: 60

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
source "${PROJECT_ROOT}/modules/04-ssh-port-helpers.sh"
source "${PROJECT_ROOT}/modules/05-ufw-helpers.sh"

# Test metadata
TEST_NAME="ssh-rollback"
TEST_DESCRIPTION="Automatic rollback on connection timeout"

# @type:        Orchestrator
# @description: Set up initial state for SSH rollback test
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
test::setup() {
    test::log_info "Setting up SSH rollback test..."
    
    # Clean system state - remove any existing BSSS SSH rules
    test::log_info "Cleaning SSH state..."
    ssh::delete_all_bsss_rules
    
    # Remove any existing BSSS UFW rules
    test::log_info "Cleaning UFW state..."
    ufw::delete_all_bsss_rules
    
    test::log_validation "Setup complete"
    return 0
}

# @type:        Orchestrator
# @description: Clean up system state after SSH rollback test
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
test::cleanup() {
    test::log_info "Cleaning up SSH rollback test..."
    
    # Remove BSSS SSH rules created during test (should already be removed by rollback)
    test::log_info "Cleaning SSH state..."
    ssh::delete_all_bsss_rules
    
    # Remove BSSS UFW rules created during test (should already be removed by rollback)
    test::log_info "Cleaning UFW state..."
    ufw::delete_all_bsss_rules
    
    test::log_validation "Cleanup complete"
    return 0
}

# @type:        Orchestrator
# @description: Validate SSH rollback test results
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - validation passed
#               1 - validation failed
test::custom_validate() {
    local log_file="$1"
    
    test::log_info "Validating SSH rollback test results..."
    
    # Check if BSSS SSH rule was removed by rollback
    test::log_info "Checking BSSS SSH rule removed..."
    local ssh_config_path="${SSH_CONFIGD_DIR%/}/${BSSS_SSH_CONFIG_FILE_NAME}"
    if [[ -f "$ssh_config_path" ]]; then
        test::log_fail "Custom validation" "BSSS SSH config file still exists after rollback: $ssh_config_path"
        return 1
    fi
    test::log_validation "BSSS SSH rule removed: $ssh_config_path"
    
    # Check if UFW rule was removed by rollback
    test::log_info "Checking UFW rule removed..."
    local ufw_rule_count
    ufw_rule_count=$(ufw::get_all_bsss_rules | tr -d '\0' | wc -l)
    if [[ "$ufw_rule_count" -gt 0 ]]; then
        test::log_fail "Custom validation" "BSSS UFW rule still exists after rollback ($ufw_rule_count rule(s))"
        return 1
    fi
    test::log_validation "BSSS UFW rule removed"
    
    # Check if rollback executed
    # Look for rollback markers in log file
    test::log_info "Checking rollback execution..."
    if grep -qi "rollback" "$log_file"; then
        test::log_validation "Rollback executed"
    else
        test::log_fail "Custom validation" "Rollback did not execute (no rollback markers found in log)"
        return 1
    fi
    
    test::log_validation "Custom validation passed"
    return 0
}

# @type:        Orchestrator
# @description: Run SSH rollback test scenario
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
    export TEST_MODULE="04-ssh-port-modify.sh"
    
    # CRITICAL: Set TEST_FAIL_CONFIRMATION to simulate timeout
    # This will make the connection confirmation prompt return code 2 (cancellation)
    # which triggers rollback
    export TEST_FAIL_CONFIRMATION="connected"
    
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
    
    test::log_info "Running SSH rollback test"
    test::log_info "Log file: $log_file"
    test::log_info "Simulating timeout via TEST_FAIL_CONFIRMATION"
    
    # Run BSSS in test mode and capture exit code
    # CRITICAL: The exit code must be captured and validated
    # BSSS exit codes: 0 = success, 2 = cancellation, 3 = rollback
    # CRITICAL: Do NOT pipe input - use TEST_MODE and TEST_FAIL_CONFIRMATION
    sudo TEST_SCENARIO="$TEST_SCENARIO" TEST_MODULE="$TEST_MODULE" bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    # Validate process lifecycle
    test::log_info "Validating process lifecycle..."
    if ! test::validate_lifecycle "$log_file"; then
        test::cleanup
        return 1
    fi
    
    # Validate exit code (expecting 3 for rollback)
    # CRITICAL: Exit code 3 is a VALID outcome for this scenario (successful rollback)
    test::log_info "Validating exit code (expecting 3 for rollback)..."
    if ! test::validate_exit_code "$exit_code" "3"; then
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
