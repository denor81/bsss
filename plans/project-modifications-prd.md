# BSSS Project Modifications for Testing Support PRD

## 1. Overview

**Objective:** Make minimal, non-invasive modifications to the BSSS project to enable automated testing while maintaining backward compatibility and production code quality.

**Scope:**
- Add file logging capability
- Add test mode flag
- Add non-interactive mode for user confirmation
- Enhance process tracking for validation

**Non-Goals:**
- Changing core business logic
- Breaking existing functionality
- Adding complex dependencies
- Changing the way modules work in production

---

## 2. Modification Summary

| File | Changes | Impact | Priority |
|------|---------|--------|----------|
| `lib/vars.conf` | Add test configuration variables | Low | HIGH |
| `lib/logging.sh` | Add file logging support | Medium | HIGH |
| `lib/user_confirmation.sh` | Add test mode functions | Low | HIGH |
| `local-runner.sh` | Add test mode parameter | Low | HIGH |
| `bsss-main.sh` | No changes required | N/A | N/A |
| `modules/*.sh` | No changes required (optional) | Low | MEDIUM |
| `utils/rollback.sh` | No changes required | N/A | N/A |

**Total Lines to Add:** ~100-150 lines  
**Total Lines to Modify:** ~20-30 lines  
**Risk Level:** LOW (non-invasive, backward compatible)

---

## 3. Detailed Modifications

### 3.1 lib/vars.conf

**Purpose:** Add configuration variables for test mode

**Changes:**

```bash
# Add to end of file (after line 26)

# ============================================================================
# TEST MODE CONFIGURATION
# ============================================================================

# Test mode flag (default: false)
# When true: enables non-interactive mode, file logging
readonly TEST_MODE="${TEST_MODE:-false}"

# Log mode: terminal | file | both (default: terminal)
readonly LOG_MODE="${LOG_MODE:-terminal}"

# Log file path (only used if LOG_MODE is file or both)
# Default: /tmp/bsss-tests/bsss-<timestamp>.log
readonly LOG_FILE="${LOG_FILE:-}"

# Test log directory (for test scenarios)
readonly TEST_LOG_DIR="${TEST_LOG_DIR:-/tmp/bsss-tests/logs}"

# Test timeout in seconds (default: 30)
readonly TEST_TIMEOUT="${TEST_TIMEOUT:-30}"

# Test scenario name (for log identification)
readonly TEST_SCENARIO="${TEST_SCENARIO:-}"
```

**Impact:** None - new variables only, no existing code affected

**Validation:** Run existing tests (if any) to ensure no regressions

---

### 3.2 lib/logging.sh

**Purpose:** Add file logging capability without breaking existing terminal output

**Changes:**

#### 3.2.1 Add Helper Functions

```bash
# Add after line 15 (after SYMBOL_ERROR definition)

# ============================================================================
# FILE LOGGING SUPPORT
# ============================================================================

# @type:        Sink
# @description: Writes message to log file if LOG_FILE is set
# @params:      message - Message to write
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log::to_file() {
    local message="$1"
    
    # Only write to file if LOG_FILE is set and writable
    if [[ -n "${LOG_FILE:-}" ]]; then
        # Ensure log directory exists
        local log_dir
        log_dir="$(dirname "$LOG_FILE")"
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" 2>/dev/null || true
        fi
        
        # Write to file
        echo "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# @type:        Sink
# @description: Generates structured log entry with timestamp
# @params:      level - Log level (INFO, WARN, ERROR, etc.)
#               module - Module name
#               pid - Process ID
#               message - Log message
# @stdin:       нет
# @stdout:      Structured log string
# @exit_code:   0 - всегда
log::format_entry() {
    local level="$1"
    local module="$2"
    local pid="$3"
    local message="$4"
    
    # ISO 8601 timestamp with milliseconds
    local timestamp
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S.%3NZ')"
    
    # Structured format: TIMESTAMP|LEVEL|MODULE|PID|MESSAGE
    printf '%s|%s|%s|%s|%s' "$timestamp" "$level" "$module" "$pid" "$message"
}
```

#### 3.2.2 Modify Existing Functions

**Update log_start() (lines 111-113):**

```bash
# BEFORE:
log_start() {
    echo -e "$SYMBOL_INFO [${1:-$CURRENT_MODULE_NAME}]>>start>>[PID: ${2:-$$}]" >&2
}

# AFTER:
log_start() {
    local module_name="${1:-$CURRENT_MODULE_NAME}"
    local pid="${2:-$$}"
    local message="$SYMBOL_INFO [${module_name}]>>start>>[PID: ${pid}]"
    
    # Terminal output (existing behavior)
    echo -e "$message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$module_name" "$pid" ">>start>>")"
        log::to_file "$structured_message"
    fi
}
```

**Update log_stop() (lines 122-125):**

```bash
# BEFORE:
log_stop() {
    echo >&2
    echo -e "$SYMBOL_INFO [${1:-$CURRENT_MODULE_NAME}]>>stop>>[PID: ${2:-$$}]" >&2
}

# AFTER:
log_stop() {
    local module_name="${1:-$CURRENT_MODULE_NAME}"
    local pid="${2:-$$}"
    
    # Terminal output (existing behavior)
    echo >&2
    echo -e "$SYMBOL_INFO [${module_name}]>>stop>>[PID: ${pid}]" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$module_name" "$pid" ">>stop>>")"
        log::to_file "$structured_message"
    fi
}
```

**Update log_info() (lines 44-46):**

```bash
# BEFORE:
log_info() {
    echo -e "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $1" >&2
}

# AFTER:
log_info() {
    local message="$1"
    local terminal_message="$SYMBOL_INFO [$CURRENT_MODULE_NAME] $message"
    
    # Terminal output (existing behavior)
    echo -e "$terminal_message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
}
```

**Similar updates for:**
- `log_error()` - level: ERROR
- `log_success()` - level: SUCCESS
- `log_warn()` - level: WARN
- `log_attention()` - level: ATTENTION
- `log_actual_info()` - level: INFO

**Impact:** Low - existing behavior preserved, file output is additive

**Validation:**
1. Run `sudo bash local-runner.sh` - should work exactly as before
2. Run with test mode - should create log file
3. Verify log file format is correct

---

### 3.3 lib/user_confirmation.sh

**Purpose:** Add non-interactive mode for testing

**Note:** Need to see the current implementation first. Let me read this file.

**Assumption:** Based on the code review, `io::confirm_action` and `io::ask_value` are the main interactive functions.

**Changes:**

#### 3.3.1 Add Test Mode Wrapper Functions

```bash
# Add at end of file

# ============================================================================
# TEST MODE SUPPORT
# ============================================================================

# @type:        Filter
# @description: Non-interactive version of io::confirm_action for test mode
#               Returns success (0) in test mode, otherwise calls interactive version
# @params:      prompt - Prompt message
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - success/yes
#               1 - no
#               2 - cancelled
io::confirm_action_test() {
    local prompt="$1"
    
    # In test mode, always return success unless TEST_FAIL_CONFIRMATION is set
    if [[ "$TEST_MODE" == "true" ]]; then
        # Check if this specific prompt should fail (for testing error paths)
        if [[ -n "${TEST_FAIL_CONFIRMATION:-}" ]] && [[ "$prompt" == *"$TEST_FAIL_CONFIRMATION"* ]]; then
            return 1
        fi
        return 0
    fi
    
    # Normal interactive mode
    io::confirm_action "$prompt"
}

# @type:        Filter
# @description: Non-interactive version of io::ask_value for test mode
#               Returns predefined value in test mode, otherwise calls interactive version
# @params:      prompt - Prompt message
#               default - Default value
#               regex - Validation regex
#               range - Display range
#               test_value - Value to return in test mode (optional)
# @stdin:       нет
# @stdout:      value\0
# @exit_code:   0 - success
#               1 - validation failed
io::ask_value_test() {
    local prompt="$1"
    local default="$2"
    local regex="$3"
    local range="$4"
    local test_value="${5:-$default}"
    
    # In test mode, return predefined value
    if [[ "$TEST_MODE" == "true" ]]; then
        printf '%s\0' "$test_value"
        return 0
    fi
    
    # Normal interactive mode
    io::ask_value "$prompt" "$default" "$regex" "$range"
}
```

#### 3.3.2 Modify Existing Interactive Functions (Optional)

**Option A: Keep existing functions, use test wrappers**
- Pros: No changes to existing code
- Cons: Need to update all call sites

**Option B: Modify existing functions to check test mode internally**
- Pros: Transparent, no call site changes needed
- Cons: Slightly more complex logic

**Recommendation:** Option B - modify existing functions for transparency

**Example modification:**

```bash
# Modify io::confirm_action to check TEST_MODE
io::confirm_action() {
    local prompt="$1"
    
    # Test mode: return success by default
    if [[ "$TEST_MODE" == "true" ]]; then
        if [[ -n "${TEST_FAIL_CONFIRMATION:-}" ]] && [[ "$prompt" == *"$TEST_FAIL_CONFIRMATION"* ]]; then
            return 1
        fi
        return 0
    fi
    
    # Original interactive logic...
    # (keep existing implementation)
}
```

**Impact:** Low - test mode is additive, interactive mode unchanged

**Validation:**
1. Run interactively - should work as before
2. Run in test mode - should skip prompts
3. Verify return codes are correct

---

### 3.4 local-runner.sh

**Purpose:** Add test mode command-line flag

**Changes:**

#### 3.4.1 Update Parameter Constants

```bash
# Line 11 - BEFORE:
readonly ALLOWED_PARAMS="hu"

# Line 11 - AFTER:
readonly ALLOWED_PARAMS="hut"

# Line 12 - BEFORE:
readonly ALLOWED_PARAMS_HELP="[-h помощь | -u удаление]"

# Line 12 - AFTER:
readonly ALLOWED_PARAMS_HELP="[-h помощь | -u удаление | -t тестовый режим]"
```

#### 3.4.2 Update parse_params Function

```bash
# Lines 35-42 - Add test mode case:
while getopts ":$allowed_params" opt "$@"; do
    case "${opt}" in
        h)  ACTION="help" ;;
        u)  ACTION="uninstall" ;;
        t)  ACTION="test" ;;
        \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params"; return 1 ;;
        :)  log_error "Параметр -$OPTARG требует значение"; return 1 ;;
    esac
done
```

#### 3.4.3 Add Test Mode Runner

```bash
# Add after run_default() function (after line 77)

# @type:        Orchestrator
# @description: Запускает основной скрипт в тестовом режиме
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   не возвращается (exec)
run_test_mode() {
    # Set test mode environment variables
    export TEST_MODE="true"
    export LOG_MODE="both"
    
    # Generate log file path if not set
    if [[ -z "${LOG_FILE:-}" ]]; then
        local timestamp
        timestamp="$(date +%s)"
        local scenario_name="${TEST_SCENARIO:-default}"
        export LOG_FILE="${TEST_LOG_DIR}/bsss-${scenario_name}-${timestamp}.log"
    fi
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    log_info "Запуск в тестовом режиме"
    log_info "Лог файл: $LOG_FILE"
    
    # Execute main script
    exec bash "${MAIN_DIR_PATH%/}/$MAIN_FILE"
}
```

#### 3.4.4 Update main Function

```bash
# Lines 90-94 - Add test case:
case "$ACTION" in
    help)      show_help ;;
    uninstall) run_uninstall ;;
    test)      run_test_mode ;;
    *)         run_default ;;
esac
```

**Impact:** Low - new flag, existing behavior unchanged

**Validation:**
1. Run `sudo bash local-runner.sh -h` - should show new flag
2. Run `sudo bash local-runner.sh -t` - should create log file
3. Verify log file is created and contains correct data

---

### 3.5 modules/*.sh (Optional Enhancement)

**Purpose:** Enhanced process tracking for better validation

**Status:** OPTIONAL - not required for initial implementation

**Potential Enhancement:**

Add parent-child relationship tracking in modules:

```bash
# In each module, replace log_start with enhanced version:
log_start_with_parent() {
    local module_name="${1:-$CURRENT_MODULE_NAME}"
    local pid="${2:-$$}"
    local parent_pid="${PPID:-}"
    
    # Log parent relationship
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$module_name" "$pid" "parent:$parent_pid")"
        log::to_file "$structured_message"
    fi
    
    log_start "$module_name" "$pid"
}
```

**Recommendation:** Defer to Phase 2 or 3 - not critical for initial testing

---

## 4. Backward Compatibility

### 4.1 Compatibility Matrix

| Scenario | Behavior | Status |
|----------|----------|--------|
| Normal run: `sudo bash local-runner.sh` | Terminal output only, interactive | ✅ Compatible |
| Help: `sudo bash local-runner.sh -h` | Shows help with new flag | ✅ Compatible |
| Uninstall: `sudo bash local-runner.sh -u` | Uninstalls normally | ✅ Compatible |
| Test mode: `sudo bash local-runner.sh -t` | Non-interactive, file logging | ✅ New feature |

### 4.2 Default Behavior

**All defaults remain unchanged:**
- `TEST_MODE=false` - interactive mode by default
- `LOG_MODE="terminal"` - terminal output only by default
- `LOG_FILE=""` - no file logging by default
- All existing functions work exactly as before

### 4.3 Migration Path

**No migration required:**
- Existing usage patterns continue to work
- Test mode is opt-in via `-t` flag
- File logging is opt-in via environment variables

---

## 5. Testing the Modifications

### 5.1 Unit Tests (Manual)

**Test 1: Normal Run (No Changes)**
```bash
sudo bash local-runner.sh
# Expected: Works exactly as before, no log file created
```

**Test 2: Help Command**
```bash
sudo bash local-runner.sh -h
# Expected: Shows help with -t flag
```

**Test 3: Test Mode**
```bash
sudo bash local-runner.sh -t
# Expected: Non-interactive, creates log file
```

**Test 4: Custom Log File**
```bash
sudo LOG_FILE=/tmp/my-test.log LOG_MODE=both bash local-runner.sh
# Expected: Creates /tmp/my-test.log
```

### 5.2 Integration Tests

**Test 5: SSH Module in Test Mode**
```bash
echo -e "Y\n2\nY\n\nconnected" | sudo bash local-runner.sh -t
# Expected: SSH port installed, log file contains process lifecycle
```

**Test 6: UFW Module in Test Mode**
```bash
echo -e "Y\n3\nY\n1\nconfirmed" | sudo bash local-runner.sh -t
# Expected: UFW enabled, log file contains process lifecycle
```

### 5.3 Validation Checklist

- [ ] Normal run works without changes
- [ ] Help command shows new flag
- [ ] Test mode creates log file
- [ ] Log file has correct format
- [ ] Process start/stop pairs are logged
- [ ] Non-interactive mode works correctly
- [ ] Exit codes are preserved
- [ ] No regressions in existing functionality

---

## 6. Rollback Plan

### 6.1 If Issues Arise

**Scenario 1: Test mode breaks production**
- Revert changes to `local-runner.sh` (remove `-t` flag)
- Keep logging enhancements (they're additive)

**Scenario 2: File logging causes performance issues**
- Set `LOG_MODE="terminal"` by default
- File logging only enabled in test mode

**Scenario 3: Non-interactive mode causes issues**
- Revert changes to `lib/user_confirmation.sh`
- Use input simulation via pipes instead

### 6.2 Rollback Commands

```bash
# Revert all changes (use git if available)
git checkout lib/logging.sh lib/user_confirmation.sh local-runner.sh lib/vars.conf

# Or manually restore from backup
cp /path/to/backup/lib/logging.sh lib/logging.sh
# ... repeat for other files
```

---

## 7. Implementation Order

### Phase 1: Core Infrastructure (Priority: HIGH)

1. **lib/vars.conf** - Add test configuration (5 minutes)
2. **lib/logging.sh** - Add file logging support (30 minutes)
3. **local-runner.sh** - Add test mode flag (15 minutes)
4. **Test:** Run normal usage to verify no regressions (10 minutes)

**Total Time:** ~1 hour

### Phase 2: Non-Interactive Support (Priority: HIGH)

5. **lib/user_confirmation.sh** - Add test mode wrappers (20 minutes)
6. **Test:** Run test mode with simulated input (15 minutes)
7. **Test:** Verify log file format (10 minutes)

**Total Time:** ~45 minutes

### Phase 3: Validation & Documentation (Priority: MEDIUM)

8. **Create test scenarios** - Basic SSH and UFW tests (30 minutes)
9. **Write documentation** - Update README with test mode usage (15 minutes)
10. **Final testing** - Run all scenarios (20 minutes)

**Total Time:** ~1 hour

**Total Implementation Time:** ~3 hours

---

## 8. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Breaking existing functionality | Low | High | Thorough testing, minimal changes |
| Performance degradation | Low | Medium | File logging is opt-in only |
| Log file format changes | Low | Medium | Document format, version it |
| Test mode not used | Medium | Low | Good documentation, clear benefits |
| Maintenance burden | Low | Low | Simple, additive changes |

---

## 9. Success Criteria

### 9.1 Functional

- [ ] All existing functionality works without changes
- [ ] Test mode flag works correctly
- [ ] File logging creates correct format
- [ ] Non-interactive mode works as expected
- [ ] Process lifecycle is captured in logs
- [ ] Exit codes are preserved

### 9.2 Non-Functional

- [ ] No performance impact on normal usage
- [ ] Code follows BSSS coding standards
- [ ] Changes are well-documented
- [ ] Backward compatibility maintained
- [ ] Easy to understand and maintain

---

## 10. Open Questions

1. **Log Format Versioning:** Should we include a version number in log files?
   - Recommendation: Yes, add `LOG_VERSION=1` to first line

2. **Log Rotation:** Should we implement automatic log rotation?
   - Recommendation: No, let test framework handle cleanup

3. **Structured Logging:** Should we use JSON format instead of pipe-delimited?
   - Recommendation: No, pipe-delimited is simpler and sufficient

4. **Test Isolation:** Should we add a "cleanup" flag to reset system state?
   - Recommendation: Yes, add `-c` flag for cleanup mode

---

## 11. Next Steps

1. **Review this PRD** with stakeholders
2. **Approve modifications**
3. **Implement Phase 1** (core infrastructure)
4. **Test Phase 1** thoroughly
5. **Implement Phase 2** (non-interactive support)
6. **Test Phase 2** thoroughly
7. **Implement Phase 3** (validation & documentation)
8. **Final review and merge**

---

## Appendix A: File Diff Summary

### lib/vars.conf
```diff
+ # ============================================================================
+ # TEST MODE CONFIGURATION
+ # ============================================================================
+ 
+ readonly TEST_MODE="${TEST_MODE:-false}"
+ readonly LOG_MODE="${LOG_MODE:-terminal}"
+ readonly LOG_FILE="${LOG_FILE:-}"
+ readonly TEST_LOG_DIR="${TEST_LOG_DIR:-/tmp/bsss-tests/logs}"
+ readonly TEST_TIMEOUT="${TEST_TIMEOUT:-30}"
+ readonly TEST_SCENARIO="${TEST_SCENARIO:-}"
```

### lib/logging.sh
```diff
+ # ============================================================================
+ # FILE LOGGING SUPPORT
+ # ============================================================================
+ 
+ log::to_file() { ... }
+ log::format_entry() { ... }
+ 
  log_start() {
-     echo -e "$SYMBOL_INFO [${1:-$CURRENT_MODULE_NAME}]>>start>>[PID: ${2:-$$}]" >&2
+     # ... terminal output
+     # ... file output (new)
  }
  
  log_stop() {
-     echo >&2
-     echo -e "$SYMBOL_INFO [${1:-$CURRENT_MODULE_NAME}]>>stop>>[PID: ${2:-$$}]" >&2
+     # ... terminal output
+     # ... file output (new)
  }
  
  # ... similar for other log functions
```

### lib/user_confirmation.sh
```diff
+ # ============================================================================
+ # TEST MODE SUPPORT
+ # ============================================================================
+ 
+ io::confirm_action_test() { ... }
+ io::ask_value_test() { ... }
+ 
+ # OR modify existing functions to check TEST_MODE
  io::confirm_action() {
+     if [[ "$TEST_MODE" == "true" ]]; then
+         # ... test mode logic
+     fi
+     
      # ... existing interactive logic
  }
```

### local-runner.sh
```diff
- readonly ALLOWED_PARAMS="hu"
+ readonly ALLOWED_PARAMS="hut"
  
- readonly ALLOWED_PARAMS_HELP="[-h помощь | -u удаление]"
+ readonly ALLOWED_PARAMS_HELP="[-h помощь | -u удаление | -t тестовый режим]"
  
  while getopts ":$allowed_params" opt "$@"; do
      case "${opt}" in
          h)  ACTION="help" ;;
          u)  ACTION="uninstall" ;;
+         t)  ACTION="test" ;;
          \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params"; return 1 ;;
          :)  log_error "Параметр -$OPTARG требует значение"; return 1 ;;
      esac
  done
  
+ run_test_mode() { ... }
  
  case "$ACTION" in
      help)      show_help ;;
      uninstall) run_uninstall ;;
+     test)      run_test_mode ;;
      *)         run_default ;;
  esac
```

---

## Appendix B: Example Log Output

### Terminal Output (Unchanged)
```
[ ] [bsss-main.sh]>>start>>[PID: 59507]
################################################################################
[ ] [01-os-check.sh] Система Ubuntu поддерживается
[ ] [04-ssh-port-modify.sh]>>start>>[PID: 59584]
[?] [04-ssh-port-modify.sh] Изменить конфигурацию SSH порта? [Y/n]: Y
[ ] [04-ssh-port-modify.sh]>>stop>>[PID: 59584]
[ ] [bsss-main.sh]>>stop>>[PID: 59507]
```

### File Output (New)
```
2026-01-20T17:30:00.123Z|INFO|bsss-main.sh|59507|>>start>>
2026-01-20T17:30:00.456Z|INFO|01-os-check.sh|59508|Система Ubuntu поддерживается
2026-01-20T17:30:01.789Z|INFO|04-ssh-port-modify.sh|59584|>>start>>
2026-01-20T17:30:05.012Z|INFO|04-ssh-port-modify.sh|59584|>>stop>>
2026-01-20T17:30:05.345Z|INFO|bsss-main.sh|59507|>>stop>>
```

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-20  
**Status:** Draft - Ready for Review
