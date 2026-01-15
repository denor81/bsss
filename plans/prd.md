# Product Requirements Document (PRD): Interactive Module Selection for Modify Modules

## Overview
Implement an interactive selection mechanism for modify-type modules in the BSSS framework. Instead of running all modify modules sequentially, provide a numbered menu allowing users to choose which module to execute, with an option to exit.

## Current State Analysis
- **run_modules_modify()** in `bsss-main.sh` currently runs all modules with `MODULE_TYPE: modify` sequentially using a pipeline that discovers and executes modules.
- Identified modify modules:
  - `modules/02-ufw-modify.sh`: Manages UFW firewall state (enable/disable)
  - `modules/04-ssh-port-modify.sh`: Manages SSH port configuration
- The system uses NUL-separated streams for data flow and preserves interactivity through proper FD management.

## Requirements
1. **Interactive Selection**: Display a numbered menu of available modify modules plus an exit option (0).
2. **Pipeline Integration**: Add a selection filter to the existing pipeline without breaking stream processing.
3. **Interactivity Preservation**: Ensure user input does not interfere with existing FD 0,1,2 separation.
4. **Compliance**: Follow AGENTS.md rules: namespacing, annotations, NUL-separators, no eval.

## Architecture Design
### New Function: orchestrator::select_modify_module
- **Type**: Filter
- **Input**: stdin - NUL-separated module paths (path\0)
- **Output**: stdout - Selected module path (path\0) or empty if exit
- **Behavior**:
  - Read all paths into an array using `mapfile -d ''`
  - Display numbered menu: "1. Module Name", "2. Module Name", "0. Exit"
  - Use `io::ask_value` for input with pattern `^[0-9]+$`
  - Validate selection range
  - Output selected path or nothing

### Modified Function: run_modules_modify
- Change from running all modules to: get paths → select one → run selected
- Pipeline: `sys::get_paths_by_mask ... | sys::get_modules_by_type "$MODULE_TYPE_MODIFY" | orchestrator::select_modify_module | xargs -0 bash`

## Implementation Plan
1. Add `orchestrator::select_modify_module` to `bsss-main.sh` with proper annotations
2. Modify `run_modules_modify` to use the new selection pipeline
3. Test with existing modules to ensure interactivity works
4. Update `function_map.txt` via `generate_function_map.sh`

## Risk Assessment
- **Interactivity**: `io::ask_value` uses `/dev/tty`, should preserve FD separation
- **Empty Selection**: If no modules, display message and exit gracefully
- **User Experience**: Menu should be clear and numbered starting from 1

## Success Criteria
- User sees numbered menu of modify modules
- Selecting a number runs the corresponding module
- Selecting 0 exits without running anything
- Existing check modules continue to run as before
- No breaking changes to current functionality