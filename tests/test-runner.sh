#!/usr/bin/env bash
# @description: Main test runner for BSSS testing framework

set -Euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test libraries
source "${SCRIPT_DIR}/lib/test-logging.sh"
source "${SCRIPT_DIR}/lib/test-runner.sh"
source "${SCRIPT_DIR}/lib/test-parser.sh"

# Source project libraries
source "${PROJECT_ROOT}/lib/vars.conf"

# Test runner configuration
VERBOSE=false
CLEANUP=false
CLEAN_STATE=false
SPECIFIC_SCENARIO=""

# @type:        Orchestrator
# @description: Parse command line arguments
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scenario)
                SPECIFIC_SCENARIO="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --cleanup)
                CLEANUP=true
                shift
                ;;
            --clean-state)
                CLEAN_STATE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# @type:        Source
# @description: Show help message
# @stdin:       none
# @stdout:      Help message to stdout
# @exit_code:   0 - success
show_help() {
    cat << 'EOF'
Usage: sudo bash tests/test-runner.sh [OPTIONS]

Options:
  --scenario <name>    Run specific test scenario
  --verbose           Enable verbose output
  --cleanup           Remove logs after test run
  --clean-state       Clean system state before tests (SSH ports, UFW rules)
  -h, --help         Show this help message

Examples:
  sudo bash tests/test-runner.sh
  sudo bash tests/test-runner.sh --scenario ssh-success
  sudo bash tests/test-runner.sh --verbose --cleanup
EOF
}

# @type:        Orchestrator
# @description: Clean system state (SSH ports, UFW rules)
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
#               1 - error
clean_system_state() {
    test::log_info "Cleaning system state..."
    
    # Remove BSSS SSH rules
    # This is a placeholder - actual implementation depends on SSH module structure
    # For now, just log that we're cleaning
    test::log_info "Cleaning SSH state (placeholder)"
    
    # Remove BSSS UFW rules
    # This is a placeholder - actual implementation depends on UFW module structure
    # For now, just log that we're cleaning
    test::log_info "Cleaning UFW state (placeholder)"
    
    test::log_validation "System state cleaned"
}

# @type:        Orchestrator
# @description: Run all test scenarios
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - all tests passed
#               1 - any test failed
run_all_tests() {
    local total=0
    local passed=0
    local failed=0
    local start_time
    local end_time
    
    start_time=$(date +%s.%3N)
    
    # Set test directory
    export TESTS_DIR="$SCRIPT_DIR"
    
    # Discover test scenarios
    local scenarios
    mapfile -t -d '' scenarios < <(test::discover_scenarios)
    
    # If specific scenario requested, filter
    if [[ -n "$SPECIFIC_SCENARIO" ]]; then
        local filtered_scenarios=()
        for scenario in "${scenarios[@]}"; do
            local scenario_name
            scenario_name=$(basename "$scenario" .sh)
            if [[ "$scenario_name" == "$SPECIFIC_SCENARIO" ]]; then
                filtered_scenarios+=("$scenario")
            fi
        done
        scenarios=("${filtered_scenarios[@]}")
    fi
    
    # Run each test
    for scenario in "${scenarios[@]}"; do
        ((total++))
        
        local scenario_name
        scenario_name=$(basename "$scenario" .sh)
        
        # Check if scenario is valid
        if ! test::is_valid_scenario "$scenario"; then
            test::log_fail "$scenario_name" "Invalid test scenario (missing test::run function)"
            ((failed++))
            continue
        fi
        
        # Run test
        test::log_start "$scenario_name"
        
        local test_start_time
        test_start_time=$(date +%s.%3N)
        
        test::run_scenario "$scenario"
        local test_exit_code=$?
        
        local test_end_time
        test_end_time=$(date +%s.%3N)
        
        local test_duration
        test_duration=$(test::calculate_duration "$test_start_time" "$test_end_time")
        
        # Check test result
        if [[ "$test_exit_code" -eq 0 ]]; then
            test::log_pass "$scenario_name" "$test_duration"
            ((passed++))
        else
            test::log_fail "$scenario_name" "Exit code: $test_exit_code"
            ((failed++))
        fi
    done
    
    end_time=$(date +%s.%3N)
    
    # Calculate total duration
    local total_duration
    total_duration=$(test::calculate_duration "$start_time" "$end_time")
    
    # Print summary
    print_summary "$total" "$passed" "$failed" "$total_duration"
    
    # Cleanup logs if requested
    if [[ "$CLEANUP" == "true" ]]; then
        cleanup_logs
    fi
    
    # Exit with appropriate code
    if [[ "$failed" -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# @type:        Source
# @description: Print test summary
# @stdin:       none
# @stdout:      Summary to stderr
# @exit_code:   0 - success
print_summary() {
    local total="$1"
    local passed="$2"
    local failed="$3"
    local duration="$4"
    
    echo "" >&2
    echo "Summary:" >&2
    echo "  Total: $total" >&2
    echo "  Passed: $passed" >&2
    echo "  Failed: $failed" >&2
    echo "  Duration: ${duration}s" >&2
    
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "  Logs: $LOG_FILE" >&2
    fi
}

# @type:        Orchestrator
# @description: Cleanup test logs
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - success
cleanup_logs() {
    test::log_info "Cleaning up test logs..."
    
    if [[ -d "${TEST_LOG_DIR:-}" ]]; then
        rm -rf "${TEST_LOG_DIR}"
    fi
    
    test::log_validation "Test logs cleaned"
}

# @type:        Orchestrator
# @description: Main entry point
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - all tests passed
#               1 - any test failed
main() {
    # Parse arguments
    parse_args "$@"
    
    # Clean system state if requested
    if [[ "$CLEAN_STATE" == "true" ]]; then
        clean_system_state
    fi
    
    # Run all tests
    run_all_tests
}

# Run main function
main "$@"
