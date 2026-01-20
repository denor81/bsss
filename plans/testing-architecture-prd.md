# BSSS Testing Architecture PRD

## 1. Overview

**Objective:** Design and implement an automated testing framework for the BSSS (Bash System Security Setup) project that can validate process lifecycle (start/stop), simulate user inputs, and verify module behavior across multiple scenarios.

**Current Pain Points:**
- Manual testing requires multiple iterations for each scenario (success, rollback, reset, etc.)
- No automated validation of process start/stop pairs
- Logs are only output to terminal, not captured for analysis
- Time-consuming to test all code paths after changes

**Target Environment:**
- Virtual machine (safe to test, can be reinstalled if needed)
- Ubuntu Linux system
- Root/sudo access available

---

## 2. Current System Analysis

### 2.1 Existing Logging System

**Current Implementation:**
- All logs output to stderr (FD2)
- Format: `[SYMBOL] [MODULE_NAME] message`
- Process tracking: `[MODULE_NAME]>>start>>[PID: XXXXX]` and `[MODULE_NAME]>>stop>>[PID: XXXXX]`

**Key Functions:**
```bash
log_start()   # Logs process start with PID
log_stop()    # Logs process stop with PID
log_info()    # Info messages
log_error()   # Error messages
log_success() # Success messages
```

**Limitations for Testing:**
- No file output (only terminal)
- No structured format for programmatic parsing
- No test mode or debug mode
- No way to capture logs for automated analysis

### 2.2 Process Hierarchy

```
bsss-main.sh (PID: X)
├── modules/04-ssh-port-modify.sh (PID: Y)
│   └── utils/rollback.sh (PID: Z) - background process
└── modules/05-ufw-modify.sh (PID: W)
    └── utils/rollback.sh (PID: V) - background process
```

**Key Observations:**
- Each module logs its own start/stop
- Rollback runs as background process
- Nested processes need proper tracking

### 2.3 User Interaction Points

**Current User Inputs Required:**
1. Main menu: "Запустить настройку?" [Y/n]
2. Module selection: "Выберите модуль [0-3]"
3. SSH module confirmation: "Изменить конфигурацию SSH порта?" [Y/n]
4. SSH action selection: "Выберите [0-2]" (reset/reinstall/exit)
5. SSH port input: "Введите новый SSH порт [1-65535, Enter for default]"
6. SSH connection confirmation: "Подтвердите подключение - введите connected"
7. UFW module confirmation: "Изменить состояние UFW?" [Y/n]
8. UFW action selection: "Выберите действие [0-1]"
9. UFW confirmation: "Подтвердите работу UFW - введите confirmed"

**Challenge:** Need to simulate these inputs automatically

---

## 3. Testing Architecture Design

### 3.1 Core Principles

1. **Non-Invasive:** Tests should not require major changes to production code
2. **Extensible:** Easy to add new test scenarios
3. **Parsable Logs:** Log format must be machine-readable
4. **Isolated:** Each test should be independent
5. **Fast:** Tests should run quickly
6. **Clear Reporting:** Easy to understand test results

### 3.2 Architecture Components

```
tests/
├── lib/
│   ├── test-logging.sh       # Test-specific logging utilities
│   ├── test-runner.sh        # Main test runner
│   └── test-parser.sh        # Log parser for validation
├── scenarios/
│   ├── ssh-success.sh        # SSH successful installation
│   ├── ssh-rollback.sh       # SSH timeout/rollback scenario
│   ├── ssh-reset.sh         # SSH reset (delete BSSS rules)
│   ├── ssh-reinstall.sh      # SSH reinstall (replace port)
│   ├── ufw-enable.sh         # UFW enable scenario
│   └── ufw-rollback.sh       # UFW timeout/rollback scenario
└── test-runner.sh            # Entry point for running all tests
```

### 3.3 Test Scenario Structure

Each test scenario is a bash script that:
1. Sets up initial state (if needed)
2. Simulates user input via pipes or expect
3. Runs the BSSS module with test flags
4. Captures output to log file
5. Validates expected behavior
6. Returns exit code (0 = pass, 1 = fail)

**Example Scenario Template:**
```bash
#!/usr/bin/env bash
# @description: Test SSH port installation with successful connection
# @expected: Process start/stop pairs match, exit code 0

# Test metadata
TEST_NAME="ssh-success"
TEST_DESCRIPTION="SSH port installation with successful connection"

# Source test library
source "${TESTS_DIR}/lib/test-logging.sh"

# Simulate user input
simulate_input() {
    # Main menu: Y
    echo "Y"
    # Module selection: 2 (SSH)
    echo "2"
    # SSH confirmation: Y
    echo "Y"
    # SSH action: Enter (default port)
    echo ""
    # Connection confirmation: connected
    echo "connected"
}

# Run test
test::run() {
    local log_file="${TEST_LOG_DIR}/${TEST_NAME}.log"
    
    # Run with simulated input and capture logs
    simulate_input | sudo bash "${BSSS_DIR}/local-runner.sh" 2> "$log_file"
    local exit_code=$?
    
    # Validate process lifecycle
    test::validate_lifecycle "$log_file"
    
    return $?
}
```

---

## 4. Required Project Modifications

### 4.1 Logging Enhancements

**Required Changes to `lib/logging.sh`:**

1. **Add Test Mode Support:**
```bash
# New variable
readonly LOG_MODE="${LOG_MODE:-terminal}"  # terminal | file | both

# New function: log to file
log_to_file() {
    local message="$1"
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "$message" >> "$LOG_FILE"
    fi
}
```

2. **Modify Existing Functions:**
```bash
# Updated log_start
log_start() {
    local module_name="${1:-$CURRENT_MODULE_NAME}"
    local pid="${2:-$$}"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S.%3N')"
    local message="$SYMBOL_INFO [${module_name}]>>start>>[PID: ${pid}]"
    
    # Terminal output (existing)
    echo -e "$message" >&2
    
    # File output (new)
    log_to_file "$timestamp $message"
}

# Similar updates for log_stop, log_info, etc.
```

3. **Add Structured Log Format:**
```bash
# Format: TIMESTAMP|LEVEL|MODULE|PID|MESSAGE
# Example: 2026-01-20 17:30:00.123|INFO|04-ssh-port-modify.sh|59584|>>start>>
```

### 4.2 Test Mode Flag

**Add to `lib/vars.conf`:**
```bash
readonly TEST_MODE="${TEST_MODE:-false}"  # true | false
readonly TEST_LOG_DIR="${TEST_LOG_DIR:-/tmp/bsss-tests/logs}"
```

**Add to `local-runner.sh`:**
```bash
# Add parameter for test mode
readonly ALLOWED_PARAMS="hut"  # t = test mode

# In parse_params:
t)  ACTION="test" ; LOG_MODE="both" ; LOG_FILE="${TEST_LOG_DIR}/bsss-$(date +%s).log" ;;
```

### 4.3 Non-Interactive Mode

**Add to `lib/user_confirmation.sh`:**
```bash
# New function for test mode
io::confirm_action_test() {
    local prompt="$1"
    # In test mode, always return success unless TEST_FAIL_CONFIRMATION is set
    if [[ "$TEST_MODE" == "true" ]]; then
        return 0
    fi
    # Normal interactive mode
    io::confirm_action "$prompt"
}

# New function for test mode value input
io::ask_value_test() {
    local prompt="$1"
    local default="$2"
    local regex="$3"
    local range="$4"
    local test_value="${5:-$default}"
    
    if [[ "$TEST_MODE" == "true" ]]; then
        printf '%s\0' "$test_value"
        return 0
    fi
    # Normal interactive mode
    io::ask_value "$prompt" "$default" "$regex" "$range"
}
```

### 4.4 Process Tracking Enhancement

**Add to `lib/logging.sh`:**
```bash
# Track parent-child relationships
declare -A PROCESS_TREE
declare -A PROCESS_START_TIMES

log_start_with_parent() {
    local module_name="${1:-$CURRENT_MODULE_NAME}"
    local pid="${2:-$$}"
    local parent_pid="${PPID:-}"
    
    # Record in process tree
    PROCESS_TREE["$pid"]="$parent_pid"
    PROCESS_START_TIMES["$pid"]="$(date '+%s.%3N')"
    
    log_start "$module_name" "$pid"
}

log_stop_with_validation() {
    local module_name="${1:-$CURRENT_MODULE_NAME}"
    local pid="${2:-$$}"
    local exit_code="${3:-0}"
    
    # Validate process was started
    if [[ -z "${PROCESS_START_TIMES[$pid]:-}" ]]; then
        log_error "Process stop without start: PID=$pid"
    fi
    
    log_stop "$module_name" "$pid"
    
    # Clean up
    unset PROCESS_TREE["$pid"]
    unset PROCESS_START_TIMES["$pid"]
}
```

---

## 5. Test Implementation Plan

### Phase 1: Infrastructure (Priority: HIGH)

**Deliverables:**
1. Modified `lib/logging.sh` with file logging support
2. Modified `lib/user_confirmation.sh` with test mode support
3. Modified `lib/vars.conf` with test configuration
4. Modified `local-runner.sh` with test mode flag
5. Test library `tests/lib/test-logging.sh`
6. Test runner `tests/test-runner.sh`

**Acceptance Criteria:**
- Running `sudo bash local-runner.sh -t` creates log file
- Log file contains structured, parsable format
- Test mode suppresses interactive prompts
- Process start/stop pairs are captured in logs

### Phase 2: Core Validation (Priority: HIGH)

**Deliverables:**
1. Log parser `tests/lib/test-parser.sh`
2. Process lifecycle validator
3. Test scenario templates

**Acceptance Criteria:**
- Parser can extract all start/stop events
- Validator detects missing start/stop pairs
- Validator detects orphaned processes (start without stop)
- Validator detects duplicate PIDs

### Phase 3: SSH Module Tests (Priority: MEDIUM)

**Deliverables:**
1. `tests/scenarios/ssh-success.sh` - Successful installation
2. `tests/scenarios/ssh-rollback.sh` - Timeout rollback
3. `tests/scenarios/ssh-reset.sh` - Reset BSSS rules
4. `tests/scenarios/ssh-reinstall.sh` - Replace existing port

**Acceptance Criteria:**
- All scenarios run without manual intervention
- Process start/stop pairs validated
- Exit codes match expectations
- System state verified after each test

### Phase 4: UFW Module Tests (Priority: MEDIUM)

**Deliverables:**
1. `tests/scenarios/ufw-enable.sh` - Enable UFW
2. `tests/scenarios/ufw-rollback.sh` - Timeout rollback

**Acceptance Criteria:**
- Same as SSH tests

### Phase 5: Integration Tests (Priority: LOW)

**Deliverables:**
1. Multi-module test scenarios
2. Error injection tests
3. Edge case tests

---

## 6. Log Format Specification

### 6.1 Structured Format

**Standard Log Entry:**
```
TIMESTAMP|LEVEL|MODULE|PID|MESSAGE
```

**Fields:**
- `TIMESTAMP`: ISO 8601 format with milliseconds: `2026-01-20T17:30:00.123Z`
- `LEVEL`: INFO, WARN, ERROR, SUCCESS, ATTENTION
- `MODULE`: Script name (e.g., `04-ssh-port-modify.sh`)
- `PID`: Process ID
- `MESSAGE`: Log message

**Examples:**
```
2026-01-20T17:30:00.123Z|INFO|04-ssh-port-modify.sh|59584|>>start>>
2026-01-20T17:30:05.456Z|INFO|04-ssh-port-modify.sh|59584|Создан FIFO: /home/ubuntu/bsss/modules/../bsss_watchdog_59584.fifo
2026-01-20T17:30:10.789Z|INFO|04-ssh-port-modify.sh|59584|>>stop>>
```

### 6.2 Process Lifecycle Markers

**Start Marker:**
```
>>start>>[PID: XXXXX]
```

**Stop Marker:**
```
>>stop>>[PID: XXXXX]
```

**Rollback Start:**
```
>>rollback_start>>[PID: XXXXX]
```

**Rollback Stop:**
```
>>rollback_stop>>[PID: XXXXX]
```

### 6.3 Test Validation Rules

**Rule 1: Every start must have a stop**
- For each `>>start>>[PID: X]`, there must be a corresponding `>>stop>>[PID: X]`

**Rule 2: No orphaned processes**
- No `>>stop>>[PID: X]` without preceding `>>start>>[PID: X]`

**Rule 3: Hierarchical ordering**
- Child processes must start after parent
- Child processes must stop before parent

**Rule 4: No duplicate PIDs**
- Each PID should appear only once per test run

---

## 7. Test Runner Design

### 7.1 Main Test Runner

**File:** `tests/test-runner.sh`

**Usage:**
```bash
# Run all tests
sudo bash tests/test-runner.sh

# Run specific test
sudo bash tests/test-runner.sh --scenario ssh-success

# Run with verbose output
sudo bash tests/test-runner.sh --verbose

# Run with cleanup (remove logs after)
sudo bash tests/test-runner.sh --cleanup
```

**Features:**
1. Discover all test scenarios in `tests/scenarios/`
2. Run tests sequentially
3. Collect results
4. Generate summary report
5. Validate process lifecycle for each test
6. Exit with appropriate code (0 = all pass, 1 = any fail)

### 7.2 Test Result Format

**Console Output:**
```
[TEST] Running ssh-success...
[OK] ssh-success passed (2.3s)
[TEST] Running ssh-rollback...
[OK] ssh-rollback passed (5.1s)
[TEST] Running ssh-reset...
[FAIL] ssh-reset failed - Missing stop for PID 12345

Summary:
  Total: 3
  Passed: 2
  Failed: 1
  Duration: 7.4s
```

**JSON Report (optional):**
```json
{
  "timestamp": "2026-01-20T17:30:00Z",
  "summary": {
    "total": 3,
    "passed": 2,
    "failed": 1,
    "duration": 7.4
  },
  "tests": [
    {
      "name": "ssh-success",
      "status": "passed",
      "duration": 2.3,
      "exit_code": 0
    },
    {
      "name": "ssh-rollback",
      "status": "passed",
      "duration": 5.1,
      "exit_code": 0
    },
    {
      "name": "ssh-reset",
      "status": "failed",
      "duration": 0.0,
      "exit_code": 1,
      "error": "Missing stop for PID 12345"
    }
  ]
}
```

---

## 8. Test Scenario Examples

### 8.1 SSH Success Scenario

**File:** `tests/scenarios/ssh-success.sh`

**Objective:** Test successful SSH port installation and confirmation

**Steps:**
1. Ensure no BSSS SSH rules exist
2. Run SSH module with default port
3. Confirm connection
4. Verify:
   - bsss-main.sh start/stop
   - 04-ssh-port-modify.sh start/stop
   - rollback.sh start/stop
   - Exit code 0
   - BSSS SSH rule created
   - UFW rule created

**Input Simulation:**
```
Y          # Start configuration
2          # Select SSH module
Y          # Confirm SSH change
           # Use default port (Enter)
connected  # Confirm connection
```

### 8.2 SSH Rollback Scenario

**File:** `tests/scenarios/ssh-rollback.sh`

**Objective:** Test automatic rollback on timeout

**Steps:**
1. Ensure no BSSS SSH rules exist
2. Run SSH module with default port
3. DO NOT confirm connection (let timeout occur)
4. Verify:
   - All processes start/stop correctly
   - Rollback executes
   - BSSS SSH rule removed
   - UFW rule removed
   - Exit code 3 (rollback)

**Input Simulation:**
```
Y          # Start configuration
2          # Select SSH module
Y          # Confirm SSH change
           # Use default port (Enter)
           # No confirmation (wait for timeout)
```

---

## 9. Extensibility Design

### 9.1 Adding New Test Scenarios

**Steps:**
1. Create new file in `tests/scenarios/`
2. Follow template structure
3. Define input simulation
4. Define validation rules
5. Add metadata (name, description, expected outcome)

**Template:**
```bash
#!/usr/bin/env bash
# @name: test-name
# @description: Brief description
# @expected: Expected outcome
# @depends: [optional] Other tests this depends on
# @timeout: [optional] Max duration in seconds (default: 30)

source "${TESTS_DIR}/lib/test-logging.sh"

# Simulate user input
simulate_input() {
    # Add echo statements for each prompt
}

# Custom validation (optional)
test::custom_validate() {
    local log_file="$1"
    # Add custom validation logic
}

# Run test
test::run() {
    # Standard test execution
}
```

### 9.2 Adding New Validation Rules

**File:** `tests/lib/test-parser.sh`

**Add new function:**
```bash
test::validate_custom_rule() {
    local log_file="$1"
    # Parse log file
    # Validate rule
    # Return 0 (pass) or 1 (fail)
}
```

**Register in validator:**
```bash
test::validate_all() {
    local log_file="$1"
    
    test::validate_lifecycle "$log_file" || return 1
    test::validate_custom_rule "$log_file" || return 1
    
    return 0
}
```

### 9.3 Adding New Log Fields

**Update `lib/logging.sh`:**
```bash
# Add new field to log format
log_extended() {
    local level="$1"
    local module="$2"
    local pid="$3"
    local message="$4"
    local custom_field="$5"  # New field
    
    local timestamp="$(date '+%Y-%m-%dT%H:%M:%S.%3NZ')"
    local log_entry="${timestamp}|${level}|${module}|${pid}|${custom_field}|${message}"
    
    echo "$log_entry" >&2
    log_to_file "$log_entry"
}
```

---

## 10. Implementation Priority

### Phase 1: Foundation (Week 1)
- [ ] Modify logging.sh for file output
- [ ] Add test mode flag to vars.conf
- [ ] Add test mode support to user_confirmation.sh
- [ ] Create test library structure
- [ ] Create basic test runner

### Phase 2: Validation (Week 1-2)
- [ ] Implement log parser
- [ ] Implement process lifecycle validator
- [ ] Create test result reporting
- [ ] Add JSON report generation

### Phase 3: SSH Tests (Week 2)
- [ ] Implement ssh-success scenario
- [ ] Implement ssh-rollback scenario
- [ ] Implement ssh-reset scenario
- [ ] Implement ssh-reinstall scenario

### Phase 4: UFW Tests (Week 2-3)
- [ ] Implement ufw-enable scenario
- [ ] Implement ufw-rollback scenario

### Phase 5: Documentation & Refinement (Week 3)
- [ ] Write test documentation
- [ ] Add test coverage report
- [ ] Refine based on feedback
- [ ] Add CI/CD integration (optional)

---

## 11. Success Criteria

### 11.1 Functional Requirements

1. **Automated Testing:**
   - [ ] All scenarios run without manual intervention
   - [ ] Tests complete within reasonable time (< 30s per test)
   - [ ] Test results are clear and actionable

2. **Process Validation:**
   - [ ] Every process start has corresponding stop
   - [ ] No orphaned processes detected
   - [ ] Parent-child relationships validated

3. **Extensibility:**
   - [ ] New scenarios can be added in < 15 minutes
   - [ ] New validation rules can be added easily
   - [ ] Log format is stable and documented

4. **Reporting:**
   - [ ] Clear pass/fail indication
   - [ ] Detailed error messages for failures
   - [ ] Summary statistics provided

### 11.2 Non-Functional Requirements

1. **Performance:**
   - Test suite completes in < 5 minutes
   - Log parsing is efficient (< 1s per log file)

2. **Maintainability:**
   - Code follows BSSS coding standards
   - Well-documented functions
   - Clear separation of concerns

3. **Reliability:**
   - Tests are idempotent (can be run multiple times)
   - Tests clean up after themselves
   - No side effects on system state

---

## 12. Risks & Mitigations

### 12.1 Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Test mode affects production code | HIGH | Use feature flags, thorough testing before merge |
| Log format changes break parser | MEDIUM | Version log format, backward compatibility |
| Simulated input doesn't match real user behavior | MEDIUM | Test with real users, validate scenarios |
| Background processes not captured | HIGH | Ensure all processes log start/stop |

### 12.2 Implementation Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Too many changes to production code | MEDIUM | Minimize changes, use test mode flag |
| Tests are flaky/unreliable | HIGH | Add retries, fix root causes |
| Test suite takes too long | MEDIUM | Parallel execution, optimize tests |

---

## 13. Open Questions

1. **Log Retention:** How long should test logs be kept?
   - Option A: Delete after each run (default)
   - Option B: Keep last N runs
   - Option C: Archive by date

2. **Test Isolation:** Should tests run in containers/chroot?
   - Option A: Run on VM directly (current plan)
   - Option B: Use containers for isolation
   - Option C: Use chroot for partial isolation

3. **Input Simulation Method:**
   - Option A: Pipe input via echo (simple)
   - Option B: Use expect tool (more robust)
   - Option C: Custom input simulator (most control)

4. **Test Execution Order:**
   - Option A: Alphabetical
   - Option B: Dependency-based
   - Option C: Manual specification

---

## 14. Next Steps

1. **Review this PRD** with stakeholders
2. **Approve Phase 1** (foundation) implementation
3. **Create detailed implementation plan** for Phase 1
4. **Begin implementation** following BSSS coding standards
5. **Iterate based on feedback**

---

## Appendix A: File Structure

```
bsss/
├── lib/
│   ├── logging.sh              # MODIFY: Add file logging
│   ├── user_confirmation.sh    # MODIFY: Add test mode support
│   └── vars.conf               # MODIFY: Add test config
├── tests/                      # NEW: Test directory
│   ├── lib/
│   │   ├── test-logging.sh     # Test logging utilities
│   │   ├── test-runner.sh      # Test execution engine
│   │   └── test-parser.sh      # Log parser & validator
│   ├── scenarios/
│   │   ├── ssh-success.sh
│   │   ├── ssh-rollback.sh
│   │   ├── ssh-reset.sh
│   │   ├── ssh-reinstall.sh
│   │   ├── ufw-enable.sh
│   │   └── ufw-rollback.sh
│   ├── logs/                   # Test log output directory
│   └── test-runner.sh          # Main test entry point
├── modules/
│   ├── 04-ssh-port-modify.sh   # MODIFY: Use enhanced logging
│   └── 05-ufw-modify.sh        # MODIFY: Use enhanced logging
└── local-runner.sh             # MODIFY: Add test mode flag
```

---

## Appendix B: Example Test Output

```
$ sudo bash tests/test-runner.sh --verbose

[TEST] Running ssh-success...
[INFO] Starting SSH port installation test
[INFO] Simulating user input: Y,2,Y,,connected
[INFO] Running BSSS in test mode
[INFO] Capturing logs to /tmp/bsss-tests/logs/ssh-success-1705770600.log
[OK] Process lifecycle validated
[OK] Exit code: 0 (expected: 0)
[OK] BSSS SSH rule created
[OK] UFW rule created
[OK] ssh-success passed (2.3s)

[TEST] Running ssh-rollback...
[INFO] Starting SSH rollback test
[INFO] Simulating user input: Y,2,Y,
[INFO] Running BSSS in test mode
[INFO] Capturing logs to /tmp/bsss-tests/logs/ssh-rollback-1705770603.log
[OK] Process lifecycle validated
[OK] Exit code: 3 (expected: 3)
[OK] Rollback executed
[OK] BSSS SSH rule removed
[OK] UFW rule removed
[OK] ssh-rollback passed (5.1s)

Summary:
  Total: 2
  Passed: 2
  Failed: 0
  Duration: 7.4s
  Logs: /tmp/bsss-tests/logs/
```

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-20  
**Status:** Draft - Ready for Review
