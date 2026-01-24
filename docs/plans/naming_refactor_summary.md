# Function Naming Convention Refactor Summary

**Date:** 2025-01-25
**Commit Range:** PRE-REFACTOR -> POST-REFACTOR

## Overview
Systematic refactoring of all function names to follow unified `domain::subdomain::action` convention with maximum 3 levels of nesting.

## Statistics
- Total functions renamed: 60+
- Files modified: 15+
- New domains introduced: 2 (runner, rollback)
- New subdomains: 10+

## Major Changes

### New Domains
- `runner::` - Module execution and selection (previously no prefix)
- `rollback::orchestrator::` - Rollback operations (previously orchestrator::*)

### SSH Functions
- `ssh::install_new_port` → `ssh::port::install_new`
- `ssh::get_user_choice` → `ssh::ui::get_new_port`
- `ssh::reset_and_pass` → `ssh::rule::reset_and_pass`
- `ssh::is_port_busy` → `ssh::port::is_port_busy`
- `ssh::generate_free_random_port` → `ssh::port::generate_free_random_port`

### UFW Functions
- `ufw::get_menu_items` → `ufw::menu::get_items`
- `ufw::display_menu` → `ufw::menu::display`
- `ufw::execute_action` → `ufw::orchestrator::execute_action`
- `ufw::toggle` → `ufw::ui::toggle`
- `ufw::apply_changes` → `ufw::rule::apply_changes`

### Orchestrators
- `orchestrator::actions_after_port_change` → `ssh::orchestrator::actions_after_port_change`
- `orchestrator::run_ufw_module` → `ufw::orchestrator::run_module`
- `orchestrator::watchdog_start` → `rollback::orchestrator::watchdog_start`
- `orchestrator::rollback` → `rollback::orchestrator::full`

### System Functions
- `sys::get_update_command` → `sys::update::get_command`
- `sys::execute_update` → `sys::update::execute`
- `sys::update_system` → `sys::update::orchestrator`
- `sys::restart_services` → `sys::service::restart`
- `sys::validate_sshd_config` → `sys::file::validate_sshd_config`

### Runner Functions
- `run_modules_polling` → `runner::module::run_check`
- `orchestrator::select_modify_module` → `runner::module::select_modify`
- `run_modules_modify` → `runner::module::run_modify`

## Naming Rules Applied

### Principle: domain::subdomain::action
- Domain: Main area (ssh, ufw, sys, runner, rollback)
- Subdomain: Specific domain (menu, port, rule, file, service)
- Action: What happens (install, delete, validate, restart)

### Duplication Rules
- **Allowed when:** Without it loses meaning or improves clarity
  - `ssh::port::generate_free_random_port` (not `generate_free_random`)
  - `ssh::port::is_port_busy` (better than `is_busy`)
- **Not required when:** Subdomain already indicates the object
  - `ufw::ping::is_configured` (not `is_ping_configured`)

### Orchestrator Pattern
- Old: `orchestrator::*` (ambiguous domain)
- New: `domain::orchestrator::*` (clear domain ownership)

## Verification
- All old function names removed
- Shellcheck passes (no new warnings)
- All modules source successfully
- Function map updated and verified

## Documentation
- Added section 13 to AGENTS.md with full naming standard
- Updated examples in section 9
- Created mapping table for reference

## Breaking Changes
All function names changed - this is a breaking change. Any external scripts depending on BSSS functions will need updates.

## Future Work
- Consider adding deprecation aliases for external compatibility
- Add automated tests for naming convention compliance
- Consider linter rule for naming convention
