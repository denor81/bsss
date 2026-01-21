#!/usr/bin/env bash
# @description: Log parser and validator for BSSS testing framework

# @type:        Filter
# @description: Extract all start/stop events from log file
# @stdin:       Log file path
# @stdout:      NUL-separated process events (PID|TYPE|TIMESTAMP)
# @exit_code:   0 - success
#               1 - error
test::parse_lifecycle_events() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Error: Log file not found: $log_file" >&2
        return 1
    fi
    
    # Extract lines containing >>start>> or >>stop>>
    # Format: TIMESTAMP|LEVEL|MODULE|PID|MESSAGE
    # Extract PID and TYPE from MESSAGE field
    grep -E ">>(start|stop)>>" "$log_file" | while IFS='|' read -r timestamp level module pid message; do
        # Extract PID from message: >>start>>[PID: XXXXX]
        local event_pid
        event_pid=$(echo "$message" | grep -oP 'PID: \K\d+')
        
        # Extract type from message
        local event_type
        if [[ "$message" == *">>start>>"* ]]; then
            event_type="start"
        elif [[ "$message" == *">>stop>>"* ]]; then
            event_type="stop"
        fi
        
        # Output: PID|TYPE|TIMESTAMP
        printf '%s|%s|%s\0' "$event_pid" "$event_type" "$timestamp"
    done
}

# @type:        Validator
# @description: Validate process lifecycle (every start must have a stop)
# @stdin:       none
# @stdout:      Validation result to stderr
# @exit_code:   0 - valid
#               1 - invalid
test::validate_lifecycle() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        test::log_fail "Lifecycle validation" "Log file not found: $log_file"
        return 1
    fi
    
    # Parse events
    local events
    mapfile -t -d '' events < <(test::parse_lifecycle_events "$log_file")
    
    # Track process states
    declare -A process_states
    declare -A process_start_times
    
    # Process events
    for event in "${events[@]}"; do
        IFS='|' read -r pid type timestamp <<< "$event"
        
        case "$type" in
            start)
                if [[ -n "${process_states[$pid]:-}" ]]; then
                    test::log_fail "Lifecycle validation" "Duplicate start for PID $pid"
                    return 1
                fi
                process_states["$pid"]="started"
                process_start_times["$pid"]="$timestamp"
                ;;
            stop)
                if [[ -z "${process_states[$pid]:-}" ]]; then
                    test::log_fail "Lifecycle validation" "Stop without start for PID $pid"
                    return 1
                fi
                if [[ "${process_states[$pid]}" != "started" ]]; then
                    test::log_fail "Lifecycle validation" "Invalid state for PID $pid: ${process_states[$pid]}"
                    return 1
                fi
                process_states["$pid"]="stopped"
                ;;
        esac
    done
    
    # Check for orphaned processes (started but not stopped)
    for pid in "${!process_states[@]}"; do
        if [[ "${process_states[$pid]}" == "started" ]]; then
            test::log_fail "Lifecycle validation" "Missing stop for PID $pid"
            return 1
        fi
    done
    
    test::log_validation "Process lifecycle validated"
    return 0
}

# @type:        Validator
# @description: Validate exit code against expected values
# @stdin:       none
# @stdout:      Validation result to stderr
# @exit_code:   0 - valid
#               1 - invalid
test::validate_exit_code() {
    local actual_code="$1"
    local expected_codes="$2"  # Comma-separated list, e.g., "0,2,3"
    
    # Convert to array
    IFS=',' read -ra expected_array <<< "$expected_codes"
    
    # Check if actual code is in expected list
    for code in "${expected_array[@]}"; do
        if [[ "$actual_code" == "$code" ]]; then
            test::log_validation "Exit code: $actual_code (expected: $expected_codes)"
            return 0
        fi
    done
    
    test::log_fail "Exit code validation" "Expected $expected_codes, got $actual_code"
    return 1
}
