#!/usr/bin/env bash
# @name: ssh-reinstall
# @description: Test SSH reinstall (replace existing port)
# @expected: Exit code 0, process lifecycle validated, old port removed, new port installed
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
source "${PROJECT_ROOT}/modules/04-ssh-port-helpers.sh"
source "${PROJECT_ROOT}/modules/05-ufw-helpers.sh"

# Test metadata
TEST_NAME="ssh-reinstall"
TEST_DESCRIPTION="SSH reinstall (replace existing port)"

# Global variable to store initial port for validation
TEST_INITIAL_PORT=""

# @type:        Orchestrator
# @description: Set up initial state for SSH reinstall test
#               Create BSSS SSH and UFW rules with an initial port first, so reinstall has something to replace
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
test::setup() {
    test::log_info "Setting up SSH reinstall test..."
    
    # First, clean any existing BSSS rules to ensure clean state
    test::log_info "Cleaning existing SSH state..."
    ssh::delete_all_bsss_rules
    
    test::log_info "Cleaning existing UFW state..."
    ufw::delete_all_bsss_rules
    
    # Generate a random free port for initial setup
    local test_port
    test_port=$(ssh::generate_free_random_port)
    TEST_INITIAL_PORT="$test_port"
    test::log_info "Generated initial test port: $TEST_INITIAL_PORT"
    
    # Create BSSS SSH rule to test reinstall functionality
    test::log_info "Creating initial BSSS SSH rule for reinstall test..."
    printf '%s\0' "$test_port" | ssh::create_bsss_config_file
    
    # Create BSSS UFW rule to test reinstall functionality
    test::log_info "Creating initial BSSS UFW rule for reinstall test..."
    printf '%s\0' "$test_port" | ufw::add_bsss_rule
    
    test::log_validation "Setup complete - BSSS SSH and UFW rules created with port $TEST_INITIAL_PORT"
    return 0
}

# @type:        Orchestrator
# @description: Clean up system state after SSH reinstall test
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
test::cleanup() {
    test::log_info "Cleaning up SSH reinstall test..."
    
    # Remove any remaining BSSS SSH rules
    test::log_info "Cleaning SSH state..."
    ssh::delete_all_bsss_rules
    
    # Remove any remaining BSSS UFW rules
    test::log_info "Cleaning UFW state..."
    ufw::delete_all_bsss_rules
    
    test::log_validation "Cleanup complete"
    return 0
}

# @type:        Orchestrator
# @description: Validate SSH reinstall test results
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - validation passed
#               1 - validation failed
test::custom_validate() {
    local log_file="$1"
    
    test::log_info "Validating SSH reinstall test results..."
    
    # Check if old SSH port was removed
    test::log_info "Checking old SSH port removed..."
    local ssh_config_path="${SSH_CONFIGD_DIR%/}/${BSSS_SSH_CONFIG_FILE_NAME}"
    if [[ ! -f "$ssh_config_path" ]]; then
        test::log_fail "Custom validation" "BSSS SSH config file not created after reinstall: $ssh_config_path"
        return 1
    fi
    
    # Extract the current port from the SSH config
    local current_port
    current_port=$(awk '/^\s*Port\s+/ { print $2 }' "$ssh_config_path")
    
    if [[ -z "$current_port" ]]; then
        test::log_fail "Custom validation" "Could not extract port from SSH config: $ssh_config_path"
        return 1
    fi
    
    # Verify the port has changed (reinstall should replace with a different port)
    if [[ "$current_port" == "$TEST_INITIAL_PORT" ]]; then
        test::log_fail "Custom validation" "Port was not replaced (still using initial port $TEST_INITIAL_PORT)"
        return 1
    fi
    test::log_validation "Old SSH port $TEST_INITIAL_PORT removed, new port $current_port installed"
    
    # Check if UFW rules were updated (should have rule for new port, not old port)
    test::log_info "Checking UFW rules updated..."
    local ufw_rule_count
    ufw_rule_count=$(ufw::get_all_bsss_rules | tr -d '\0' | wc -l)
    if [[ "$ufw_rule_count" -eq 0 ]]; then
        test::log_fail "Custom validation" "BSSS UFW rule not created after reinstall"
        return 1
    fi
    
    # Verify UFW rule is for the new port, not the old port
    local ufw_has_old_port
    ufw_has_old_port=$(ufw::get_all_bsss_rules | grep -qz "${TEST_INITIAL_PORT}/tcp" && echo "true" || echo "false")
    if [[ "$ufw_has_old_port" == "true" ]]; then
        test::log_fail "Custom validation" "UFW rule still exists for old port $TEST_INITIAL_PORT"
        return 1
    fi
    
    # Verify UFW rule is for the new port
    local ufw_has_new_port
    ufw_has_new_port=$(ufw::get_all_bsss_rules | grep -qz "${current_port}/tcp" && echo "true" || echo "false")
    if [[ "$ufw_has_new_port" != "true" ]]; then
        test::log_fail "Custom validation" "UFW rule not found for new port $current_port"
        return 1
    fi
    test::log_validation "UFW rules updated: old port $TEST_INITIAL_PORT removed, new port $current_port added"
    
    test::log_validation "Custom validation passed"
    return 0
}

# @type:        Orchestrator
# @description: Run SSH reinstall test scenario
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
    
    test::log_info "Running SSH reinstall test"
    test::log_info "Log file: $log_file"
    
    # Run BSSS in test mode and capture exit code
    # CRITICAL: The exit code must be captured and validated
    # BSSS exit codes: 0 = success, 2 = cancellation, 3 = rollback
    # CRITICAL: Do NOT pipe input - use TEST_MODE environment variable
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
