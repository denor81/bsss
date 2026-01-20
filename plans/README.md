# BSSS Testing Framework - Planning Documents

This directory contains Product Requirement Documents (PRDs) for implementing an automated testing framework for the BSSS project.

## Overview

The BSSS project currently requires manual testing which is time-consuming and error-prone. These PRDs outline a comprehensive testing architecture that will enable:

1. **Automated testing** of all modules and scenarios
2. **Process lifecycle validation** (start/stop pairs)
3. **Non-interactive test mode** for CI/CD integration
4. **Extensible framework** for adding new test scenarios
5. **Clear reporting** of test results

## Documents

### 1. [`testing-architecture-prd.md`](testing-architecture-prd.md)

**Purpose:** Complete design specification for the testing framework

**Contents:**
- Current system analysis
- Testing architecture design
- Log format specification
- Test scenario examples
- Implementation phases
- Success criteria

**Key Sections:**
- Phase 1: Infrastructure (logging, test mode)
- Phase 2: Core validation (log parser, process lifecycle)
- Phase 3: SSH module tests
- Phase 4: UFW module tests
- Phase 5: Integration tests

**Target Audience:** Developers, Architects, QA Engineers

### 2. [`project-modifications-prd.md`](project-modifications-prd.md)

**Purpose:** Detailed specification for minimal changes to the BSSS project to support testing

**Contents:**
- File-by-file modification specifications
- Code changes with diffs
- Backward compatibility guarantees
- Testing procedures
- Rollback plan

**Key Modifications:**
- `lib/vars.conf` - Add test configuration variables
- `lib/logging.sh` - Add file logging support
- `lib/user_confirmation.sh` - Add test mode wrappers
- `local-runner.sh` - Add `-t` test mode flag

**Impact:** ~100-150 lines added, ~20-30 lines modified, LOW risk

**Target Audience:** Developers implementing the changes

## Quick Reference

### Test Mode Usage

```bash
# Run in test mode (non-interactive, file logging)
sudo bash local-runner.sh -t

# Run with custom log file
sudo LOG_FILE=/tmp/my-test.log LOG_MODE=both bash local-runner.sh

# Run test scenario
sudo bash tests/test-runner.sh --scenario ssh-success
```

### Log Format

```
TIMESTAMP|LEVEL|MODULE|PID|MESSAGE
```

**Example:**
```
2026-01-20T17:30:00.123Z|INFO|04-ssh-port-modify.sh|59584|>>start>>
2026-01-20T17:30:05.456Z|INFO|04-ssh-port-modify.sh|59584|>>stop>>
```

### Process Lifecycle Markers

- `>>start>>[PID: XXXXX]` - Process started
- `>>stop>>[PID: XXXXX]` - Process stopped
- `>>rollback_start>>[PID: XXXXX]` - Rollback started
- `>>rollback_stop>>[PID: XXXXX]` - Rollback stopped

### Validation Rules

1. **Every start must have a stop** - No orphaned processes
2. **No stop without start** - All processes must be started first
3. **Hierarchical ordering** - Children start after parent, stop before parent
4. **No duplicate PIDs** - Each PID appears once per test run

## Implementation Timeline

### Week 1
- Day 1-2: Phase 1 - Infrastructure (logging, test mode)
- Day 3-4: Phase 2 - Core validation (parser, validator)
- Day 5: Review and testing

### Week 2
- Day 1-2: Phase 3 - SSH module tests
- Day 3-4: Phase 4 - UFW module tests
- Day 5: Review and testing

### Week 3
- Day 1-2: Phase 5 - Integration tests
- Day 3-4: Documentation and refinement
- Day 5: Final review and deployment

## File Structure After Implementation

```
bsss/
├── lib/
│   ├── logging.sh              # MODIFIED: Add file logging
│   ├── user_confirmation.sh    # MODIFIED: Add test mode
│   └── vars.conf               # MODIFIED: Add test config
├── tests/                      # NEW: Test directory
│   ├── lib/
│   │   ├── test-logging.sh     # Test utilities
│   │   ├── test-runner.sh      # Test engine
│   │   └── test-parser.sh      # Log parser
│   ├── scenarios/
│   │   ├── ssh-success.sh
│   │   ├── ssh-rollback.sh
│   │   ├── ssh-reset.sh
│   │   ├── ssh-reinstall.sh
│   │   ├── ufw-enable.sh
│   │   └── ufw-rollback.sh
│   ├── logs/                   # Test output
│   └── test-runner.sh          # Main entry point
├── modules/
│   ├── 04-ssh-port-modify.sh   # OPTIONAL: Enhanced tracking
│   └── 05-ufw-modify.sh        # OPTIONAL: Enhanced tracking
└── local-runner.sh             # MODIFIED: Add -t flag
```

## Key Design Principles

1. **Non-Invasive** - Minimal changes to production code
2. **Backward Compatible** - Existing usage patterns unchanged
3. **Extensible** - Easy to add new test scenarios
4. **Parsable** - Log format is machine-readable
5. **Isolated** - Each test is independent
6. **Fast** - Tests complete quickly

## Success Criteria

### Functional
- ✅ All scenarios run without manual intervention
- ✅ Process start/stop pairs validated
- ✅ Exit codes match expectations
- ✅ System state verified after each test

### Non-Functional
- ✅ Test suite completes in < 5 minutes
- ✅ Code follows BSSS coding standards
- ✅ Well-documented functions
- ✅ No regressions in existing functionality
- ✅ Tests are idempotent

## Next Steps

1. **Review** the PRDs in this directory
2. **Approve** the modifications in `project-modifications-prd.md`
3. **Implement** Phase 1 (infrastructure)
4. **Test** thoroughly before proceeding
5. **Iterate** based on feedback

## Questions?

Refer to individual PRDs for detailed information:
- [`testing-architecture-prd.md`](testing-architecture-prd.md) - Complete architecture design
- [`project-modifications-prd.md`](project-modifications-prd.md) - Implementation details

## Audit Summary

Both PRDs have undergone comprehensive architectural audits by senior technical architects to identify systemic issues, logical gaps, and implementation risks.

### Audit Results

**[`project-modifications-prd.md`](project-modifications-prd.md) Audit:**
- **Total Issues Identified:** 32
- **Critical Issues:** 4 (all fixed)
- **High Issues:** 2 (all fixed)
- **Medium Issues:** 12 (all fixed)
- **Low Issues:** 14 (all fixed)
- **Version:** 1.0 → 1.1
- **Status:** Audited and Corrected

**[`testing-architecture-prd.md`](testing-architecture-prd.md) Audit:**
- **Total Issues Identified:** 39
- **Critical Issues:** 4 (all fixed)
- **High Issues:** 5 (all fixed)
- **Medium Issues:** 10 (all fixed)
- **Low Issues:** 20 (all fixed)
- **Version:** 1.0 → 1.1
- **Status:** Audited and Corrected

### Key Critical Issues Resolved

1. **TTY Input Blocking** - Original design assumed `echo | bash` would work for input simulation, but [`io::ask_value()`](lib/user_confirmation.sh:24) reads from `/dev/tty`. Fixed by using TEST_MODE environment variable approach instead.

2. **Missing Newline in Log Format** - [`log::format_entry()`](plans/project-modifications-prd.md:148) was missing `\n` at end, which would make log files completely unparsable. Fixed.

3. **Incorrect Exit Codes** - Test mode functions used code 1 instead of BSSS standard code 2 for cancellation. Fixed to comply with [`AGENTS.md`](AGENTS.md:38-40).

4. **Readonly Variables Blocking Overrides** - Configuration variables declared as `readonly` would prevent test scenarios from customizing behavior. Changed to `export` to allow overrides.

5. **Rollback FD3 Logging** - [`rollback.sh`](utils/rollback.sh:20) logs to FD3 instead of FD2, which wasn't addressed in original design. Added validation rules and documentation.

6. **Missing Test Cleanup** - Original design didn't address how tests would clean up system state (SSH ports, UFW rules) between runs. Added cleanup requirements and steps.

### Remaining Concerns

Both PRDs now document remaining concerns that should be addressed in later phases:

**High Priority:**
- Background process FD3 logging integration
- TTY simulation in test mode
- Test isolation and cleanup implementation

**Medium Priority:**
- Exit code 3 (rollback) handling in test framework
- Log parser edge case handling
- Test dependencies and execution order
- JSON report generation

**Low Priority:**
- Test data management strategy
- Mock strategy for external dependencies
- Test coverage reporting
- CI/CD integration

### Audit Documentation

Each PRD now includes a comprehensive **Appendix C: Audit Findings & Resolutions** section that documents:
- Every issue found with severity level
- Why each issue was a problem
- How it was resolved
- Any remaining concerns

### Next Steps

1. **Review** the audited PRDs in this directory
2. **Review** Appendix C sections in both PRDs for complete audit details
3. **Approve** the corrected PRDs for implementation
4. **Begin Phase 1** implementation following the corrected specifications

---

**Last Updated:** 2026-01-20
**Status:** Audited and Ready for Implementation
