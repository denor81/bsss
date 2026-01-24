# Function Naming Convention Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor all function names across the BSSS project to follow unified naming convention `domain::subdomain::action`

**Architecture:** Use find+replace patterns with sed/perl to rename functions, update all function calls, verify with shellcheck, and update documentation

**Tech Stack:** Bash, sed, shellcheck, git

---

### Task 1: Create Renaming Mapping Table

**Files:**
- Create: `docs/plans/function_renaming_map.txt`

**Step 1: Create mapping file**

Create mapping file with format: `old_name|new_name|file_pattern`

```bash
cat > docs/plans/function_renaming_map.txt << 'EOF'
# Orchestrators
orchestrator::dispatch_logic|ssh::orchestrator::dispatch_logic|modules/04-ssh-port-modify.sh
orchestrator::bsss_config_exists|ssh::orchestrator::config_exists|modules/04-ssh-port-modify.sh
orchestrator::bsss_config_not_exists|ssh::orchestrator::config_not_exists|modules/04-ssh-port-modify.sh
orchestrator::install_new_port_w_guard|ssh::orchestrator::install_port_with_guard|modules/04-ssh-port-modify.sh
orchestrator::actions_after_port_change|ssh::orchestrator::actions_after_port_change|modules/04-ssh-port-helpers.sh
orchestrator::actions_after_ufw_change|ufw::orchestrator::actions_after_ufw_change|modules/05-ufw-helpers.sh
orchestrator::run_ufw_module|ufw::orchestrator::run_module|modules/05-ufw-modify.sh
orchestrator::watchdog_start|rollback::orchestrator::watchdog_start|modules/05-ufw-modify.sh
orchestrator::watchdog_stop|rollback::orchestrator::watchdog_stop|modules/05-ufw-modify.sh
orchestrator::watchdog_timer|rollback::orchestrator::watchdog_timer|utils/rollback.sh
orchestrator::stop_rollback|rollback::orchestrator::stop|utils/rollback.sh
orchestrator::immediate_rollback|rollback::orchestrator::immediate|utils/rollback.sh
orchestrator::ssh_rollback|rollback::orchestrator::ssh|utils/rollback.sh
orchestrator::ufw_rollback|rollback::orchestrator::ufw|utils/rollback.sh
orchestrator::rollback|rollback::orchestrator::full|utils/rollback.sh
orchestrator::select_modify_module|runner::module::select_modify|bsss-main.sh

# SSH functions
ssh::install_new_port|ssh::port::install_new|modules/04-ssh-port-helpers.sh
ssh::get_user_choice|ssh::ui::get_new_port|modules/04-ssh-port-helpers.sh
ssh::log_bsss_configs_w_port|ssh::config::log_bsss_with_ports|modules/04-ssh-port-helpers.sh
ssh::log_other_configs_w_port|ssh::config::log_other_with_ports|modules/04-ssh-port-helpers.sh
ssh::reset_and_pass|ssh::rule::reset_and_pass|modules/04-ssh-port-helpers.sh modules/common-helpers.sh
ssh::delete_all_bsss_rules|ssh::rule::delete_all_bsss|modules/04-ssh-port-helpers.sh
ssh::is_port_busy|ssh::port::is_port_busy|modules/04-ssh-port-helpers.sh
ssh::generate_free_random_port|ssh::port::generate_free_random_port|modules/04-ssh-port-helpers.sh
ssh::create_bsss_config_file|ssh::config::create_bsss_file|modules/04-ssh-port-helpers.sh
ssh::display_menu|ssh::ui::display_menu|modules/04-ssh-port-helpers.sh
ssh::apply_changes|ssh::rule::apply_changes|modules/04-ssh-port-helpers.sh
ssh::wait_for_port_up|ssh::port::wait_for_up|modules/04-ssh-port-helpers.sh
ssh::is_already_configured|ssh::socket::is_already_configured|modules/03-ssh-socket-helpers.sh
ssh::force_service_mode|ssh::socket::force_service_mode|modules/03-ssh-socket-helpers.sh

# UFW functions
ufw::get_menu_items|ufw::menu::get_items|modules/05-ufw-helpers.sh
ufw::display_menu|ufw::menu::display|modules/05-ufw-helpers.sh
ufw::get_user_choice|ufw::menu::get_user_choice|modules/05-ufw-helpers.sh
ufw::execute_action|ufw::orchestrator::execute_action|modules/05-ufw-helpers.sh
ufw::toggle|ufw::ui::toggle|modules/05-ufw-helpers.sh
ufw::log_status|ufw::ui::log_status|modules/05-ufw-helpers.sh
ufw::apply_changes|ufw::rule::apply_changes|modules/05-ufw-helpers.sh
ufw::confirm_success|ufw::ui::confirm_success|modules/05-ufw-helpers.sh
ufw::ping::disable|ufw::ping::disable_in_rules|modules/05-ufw-helpers.sh
ufw::reset_and_pass|ufw::rule::reset_and_pass|modules/05-ufw-helpers.sh modules/common-helpers.sh
ufw::delete_all_bsss_rules|ufw::rule::delete_all_bsss|modules/05-ufw-helpers.sh modules/common-helpers.sh
ufw::get_all_bsss_rules|ufw::rule::get_all_bsss|modules/common-helpers.sh
ufw::get_all_rules|ufw::rule::get_all|modules/common-helpers.sh
ufw::add_bsss_rule|ufw::rule::add_bsss|modules/common-helpers.sh
ufw::is_active|ufw::rule::is_active|modules/common-helpers.sh
ufw::force_disable|ufw::rule::force_disable|modules/common-helpers.sh
ufw::enable|ufw::rule::enable|modules/common-helpers.sh
ufw::log_active_ufw_rules|ufw::rule::log_active|modules/common-helpers.sh

# System functions
sys::get_update_command|sys::update::get_command|modules/02-update-system.sh
sys::execute_update|sys::update::execute|modules/02-update-system.sh
sys::update_system|sys::update::orchestrator|modules/02-update-system.sh
sys::restart_services|sys::service::restart|modules/04-ssh-port-helpers.sh
sys::validate_sshd_config|sys::file::validate_sshd_config|modules/common-helpers.sh
sys::get_paths_by_mask|sys::file::get_paths_by_mask|modules/common-helpers.sh
sys::delete_paths|sys::file::delete|modules/common-helpers.sh
EOF
```

**Step 2: Run shellcheck on current codebase**

```bash
./utils/generate_function_map.sh
shellcheck -f gcc modules/*.sh lib/*.sh utils/*.sh 2>&1 | tee docs/plans/shellcheck_baseline.txt
```

Expected: Output shows current warnings (if any)

**Step 3: Commit mapping and baseline**

```bash
git add docs/plans/function_renaming_map.txt docs/plans/shellcheck_baseline.txt
git commit -m "chore: prepare function renaming mapping and baseline"
```

---

### Task 2: Rename SSH Functions

**Files:**
- Modify: `modules/04-ssh-port-helpers.sh`
- Modify: `modules/03-ssh-socket-helpers.sh`
- Modify: `modules/04-ssh-port-modify.sh`

**Step 1: Rename function definitions in SSH files**

```bash
# modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::install_new_port()/ssh::port::install_new()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::get_user_choice()/ssh::ui::get_new_port()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::log_bsss_configs_w_port()/ssh::config::log_bsss_with_ports()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::log_other_configs_w_port()/ssh::config::log_other_with_ports()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::reset_and_pass()/ssh::rule::reset_and_pass()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::delete_all_bsss_rules()/ssh::rule::delete_all_bsss()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::is_port_busy()/ssh::port::is_port_busy()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::generate_free_random_port()/ssh::port::generate_free_random_port()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::create_bsss_config_file()/ssh::config::create_bsss_file()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::display_menu()/ssh::ui::display_menu()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::apply_changes()/ssh::rule::apply_changes()/g' modules/04-ssh-port-helpers.sh
sed -i 's/^ssh::wait_for_port_up()/ssh::port::wait_for_up()/g' modules/04-ssh-port-helpers.sh

# modules/03-ssh-socket-helpers.sh
sed -i 's/^ssh::is_already_configured()/ssh::socket::is_already_configured()/g' modules/03-ssh-socket-helpers.sh
sed -i 's/^ssh::force_service_mode()/ssh::socket::force_service_mode()/g' modules/03-ssh-socket-helpers.sh

# modules/04-ssh-port-modify.sh
sed -i 's/^orchestrator::dispatch_logic()/ssh::orchestrator::dispatch_logic()/g' modules/04-ssh-port-modify.sh
sed -i 's/^orchestrator::bsss_config_exists()/ssh::orchestrator::config_exists()/g' modules/04-ssh-port-modify.sh
sed -i 's/^orchestrator::bsss_config_not_exists()/ssh::orchestrator::config_not_exists()/g' modules/04-ssh-port-modify.sh
sed -i 's/^orchestrator::install_new_port_w_guard()/ssh::orchestrator::install_port_with_guard()/g' modules/04-ssh-port-modify.sh
```

**Step 2: Update function calls in SSH files**

```bash
# Update calls in 04-ssh-port-helpers.sh
sed -i 's/\bssh::install_new_port\b/ssh::port::install_new/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::get_user_choice\b/ssh::ui::get_new_port/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::log_bsss_configs_w_port\b/ssh::config::log_bsss_with_ports/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::log_other_configs_w_port\b/ssh::config::log_other_with_ports/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::reset_and_pass\b/ssh::rule::reset_and_pass/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::delete_all_bsss_rules\b/ssh::rule::delete_all_bsss/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::is_port_busy\b/ssh::port::is_port_busy/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::generate_free_random_port\b/ssh::port::generate_free_random_port/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::create_bsss_config_file\b/ssh::config::create_bsss_file/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::display_menu\b/ssh::ui::display_menu/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::apply_changes\b/ssh::rule::apply_changes/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::wait_for_port_up\b/ssh::port::wait_for_up/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::is_already_configured\b/ssh::socket::is_already_configured/g' modules/04-ssh-port-helpers.sh
sed -i 's/\bssh::force_service_mode\b/ssh::socket::force_service_mode/g' modules/04-ssh-port-helpers.sh

# Update calls in 04-ssh-port-modify.sh
sed -i 's/\borchestrator::dispatch_logic\b/ssh::orchestrator::dispatch_logic/g' modules/04-ssh-port-modify.sh
sed -i 's/\borchestrator::bsss_config_exists\b/ssh::orchestrator::config_exists/g' modules/04-ssh-port-modify.sh
sed -i 's/\borchestrator::bsss_config_not_exists\b/ssh::orchestrator::config_not_exists/g' modules/04-ssh-port-modify.sh
sed -i 's/\borchestrator::install_new_port_w_guard\b/ssh::orchestrator::install_port_with_guard/g' modules/04-ssh-port-modify.sh
```

**Step 3: Run shellcheck on SSH files**

```bash
shellcheck -f gcc modules/04-ssh-port-helpers.sh modules/03-ssh-socket-helpers.sh modules/04-ssh-port-modify.sh 2>&1 | tee docs/plans/ssh_shellcheck_after.txt
```

Expected: No new warnings compared to baseline

**Step 4: Commit SSH renames**

```bash
git add modules/04-ssh-port-helpers.sh modules/03-ssh-socket-helpers.sh modules/04-ssh-port-modify.sh
git commit -m "refactor: rename SSH functions to domain::subdomain::action convention"
```

---

### Task 3: Rename UFW Functions

**Files:**
- Modify: `modules/05-ufw-helpers.sh`
- Modify: `modules/05-ufw-modify.sh`
- Modify: `modules/common-helpers.sh`

**Step 1: Rename function definitions in UFW files**

```bash
# modules/05-ufw-helpers.sh
sed -i 's/^ufw::get_menu_items()/ufw::menu::get_items()/g' modules/05-ufw-helpers.sh
sed -i 's/^ufw::display_menu()/ufw::menu::display()/g' modules/05-ufw-helpers.sh
sed -i 's/^ufw::get_user_choice()/ufw::menu::get_user_choice()/g' modules/05-ufw-helpers.sh
sed -i 's/^ufw::execute_action()/ufw::orchestrator::execute_action()/g' modules/05-ufw-helpers.sh
sed -i 's/^ufw::toggle()/ufw::ui::toggle()/g' modules/05-ufw-helpers.sh
sed -i 's/^ufw::log_status()/ufw::ui::log_status()/g' modules/05-ufw-helpers.sh
sed -i 's/^ufw::apply_changes()/ufw::rule::apply_changes()/g' modules/05-ufw-helpers.sh
sed -i 's/^ufw::confirm_success()/ufw::ui::confirm_success()/g' modules/05-ufw-helpers.sh
sed -i 's/^ufw::ping::disable()/ufw::ping::disable_in_rules()/g' modules/05-ufw-helpers.sh

# modules/05-ufw-modify.sh
sed -i 's/^orchestrator::run_ufw_module()/ufw::orchestrator::run_module()/g' modules/05-ufw-modify.sh
sed -i 's/^orchestrator::watchdog_start()/rollback::orchestrator::watchdog_start()/g' modules/05-ufw-modify.sh
sed -i 's/^orchestrator::watchdog_stop()/rollback::orchestrator::watchdog_stop()/g' modules/05-ufw-modify.sh

# modules/common-helpers.sh
sed -i 's/^ufw::reset_and_pass()/ufw::rule::reset_and_pass()/g' modules/common-helpers.sh
sed -i 's/^ufw::delete_all_bsss_rules()/ufw::rule::delete_all_bsss()/g' modules/common-helpers.sh
sed -i 's/^ufw::get_all_bsss_rules()/ufw::rule::get_all_bsss()/g' modules/common-helpers.sh
sed -i 's/^ufw::get_all_rules()/ufw::rule::get_all()/g' modules/common-helpers.sh
sed -i 's/^ufw::add_bsss_rule()/ufw::rule::add_bsss()/g' modules/common-helpers.sh
sed -i 's/^ufw::is_active()/ufw::rule::is_active()/g' modules/common-helpers.sh
sed -i 's/^ufw::force_disable()/ufw::rule::force_disable()/g' modules/common-helpers.sh
sed -i 's/^ufw::enable()/ufw::rule::enable()/g' modules/common-helpers.sh
sed -i 's/^ufw::log_active_ufw_rules()/ufw::rule::log_active()/g' modules/common-helpers.sh
sed -i 's/^sys::restart_services()/sys::service::restart()/g' modules/common-helpers.sh
sed -i 's/^sys::validate_sshd_config()/sys::file::validate_sshd_config()/g' modules/common-helpers.sh
sed -i 's/^sys::get_paths_by_mask()/sys::file::get_paths_by_mask()/g' modules/common-helpers.sh
sed -i 's/^sys::delete_paths()/sys::file::delete()/g' modules/common-helpers.sh
```

**Step 2: Update function calls in UFW files**

```bash
# Update calls in 05-ufw-helpers.sh
sed -i 's/\bufw::get_menu_items\b/ufw::menu::get_items/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::display_menu\b/ufw::menu::display/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::get_user_choice\b/ufw::menu::get_user_choice/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::execute_action\b/ufw::orchestrator::execute_action/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::toggle\b/ufw::ui::toggle/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::log_status\b/ufw::ui::log_status/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::apply_changes\b/ufw::rule::apply_changes/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::confirm_success\b/ufw::ui::confirm_success/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::ping::disable\b/ufw::ping::disable_in_rules/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::reset_and_pass\b/ufw::rule::reset_and_pass/g' modules/05-ufw-helpers.sh
sed -i 's/\bufw::delete_all_bsss_rules\b/ufw::rule::delete_all_bsss/g' modules/05-ufw-helpers.sh

# Update calls in 05-ufw-modify.sh
sed -i 's/\borchestrator::run_ufw_module\b/ufw::orchestrator::run_module/g' modules/05-ufw-modify.sh
sed -i 's/\borchestrator::watchdog_start\b/rollback::orchestrator::watchdog_start/g' modules/05-ufw-modify.sh
sed -i 's/\borchestrator::watchdog_stop\b/rollback::orchestrator::watchdog_stop/g' modules/05-ufw-modify.sh
sed -i 's/\borchestrator::guard_ui_instructions\b/rollback::orchestrator::guard_ui_instructions/g' modules/05-ufw-modify.sh

# Update calls in common-helpers.sh
sed -i 's/\bufw::reset_and_pass\b/ufw::rule::reset_and_pass/g' modules/common-helpers.sh
sed -i 's/\bufw::delete_all_bsss_rules\b/ufw::rule::delete_all_bsss/g' modules/common-helpers.sh
sed -i 's/\bufw::get_all_bsss_rules\b/ufw::rule::get_all_bsss/g' modules/common-helpers.sh
sed -i 's/\bufw::get_all_rules\b/ufw::rule::get_all/g' modules/common-helpers.sh
sed -i 's/\bufw::add_bsss_rule\b/ufw::rule::add_bsss/g' modules/common-helpers.sh
sed -i 's/\bufw::is_active\b/ufw::rule::is_active/g' modules/common-helpers.sh
sed -i 's/\bufw::force_disable\b/ufw::rule::force_disable/g' modules/common-helpers.sh
sed -i 's/\bufw::enable\b/ufw::rule::enable/g' modules/common-helpers.sh
sed -i 's/\bufw::log_active_ufw_rules\b/ufw::rule::log_active/g' modules/common-helpers.sh
sed -i 's/\bsys::restart_services\b/sys::service::restart/g' modules/common-helpers.sh
sed -i 's/\bsys::validate_sshd_config\b/sys::file::validate_sshd_config/g' modules/common-helpers.sh
sed -i 's/\bsys::get_paths_by_mask\b/sys::file::get_paths_by_mask/g' modules/common-helpers.sh
sed -i 's/\bsys::delete_paths\b/sys::file::delete/g' modules/common-helpers.sh
```

**Step 3: Run shellcheck on UFW files**

```bash
shellcheck -f gcc modules/05-ufw-helpers.sh modules/05-ufw-modify.sh modules/common-helpers.sh 2>&1 | tee docs/plans/ufw_shellcheck_after.txt
```

Expected: No new warnings compared to baseline

**Step 4: Commit UFW renames**

```bash
git add modules/05-ufw-helpers.sh modules/05-ufw-modify.sh modules/common-helpers.sh
git commit -m "refactor: rename UFW and sys functions to domain::subdomain::action convention"
```

---

### Task 4: Rename System Update Functions

**Files:**
- Modify: `modules/02-update-system.sh`

**Step 1: Rename function definitions**

```bash
sed -i 's/^sys::get_update_command()/sys::update::get_command()/g' modules/02-update-system.sh
sed -i 's/^sys::execute_update()/sys::update::execute()/g' modules/02-update-system.sh
sed -i 's/^sys::update_system()/sys::update::orchestrator()/g' modules/02-update-system.sh
```

**Step 2: Update function calls**

```bash
sed -i 's/\bsys::get_update_command\b/sys::update::get_command/g' modules/02-update-system.sh
sed -i 's/\bsys::execute_update\b/sys::update::execute/g' modules/02-update-system.sh
sed -i 's/\bsys::update_system\b/sys::update::orchestrator/g' modules/02-update-system.sh
```

**Step 3: Run shellcheck**

```bash
shellcheck -f gcc modules/02-update-system.sh 2>&1 | tee docs/plans/update_shellcheck_after.txt
```

Expected: No new warnings

**Step 4: Commit system update renames**

```bash
git add modules/02-update-system.sh
git commit -m "refactor: rename sys::update functions to sys::update::subdomain::action"
```

---

### Task 5: Rename Rollback Functions

**Files:**
- Modify: `utils/rollback.sh`

**Step 1: Rename function definitions**

```bash
sed -i 's/^orchestrator::watchdog_timer()/rollback::orchestrator::watchdog_timer()/g' utils/rollback.sh
sed -i 's/^orchestrator::stop_rollback()/rollback::orchestrator::stop()/g' utils/rollback.sh
sed -i 's/^orchestrator::immediate_rollback()/rollback::orchestrator::immediate()/g' utils/rollback.sh
sed -i 's/^orchestrator::ssh_rollback()/rollback::orchestrator::ssh()/g' utils/rollback.sh
sed -i 's/^orchestrator::ufw_rollback()/rollback::orchestrator::ufw()/g' utils/rollback.sh
sed -i 's/^orchestrator::rollback()/rollback::orchestrator::full()/g' utils/rollback.sh
```

**Step 2: Update function calls across project**

```bash
# Update calls in all files
grep -rl "orchestrator::watchdog_timer\|orchestrator::stop_rollback\|orchestrator::immediate_rollback\|orchestrator::ssh_rollback\|orchestrator::ufw_rollback\|^orchestrator::rollback(" . --exclude-dir=.git | while read file; do
    sed -i 's/\bmain()\s*$/main_rollback()/g' "$file"
done

# Update orchestrator::rollback calls (not rollback::orchestrator::full)
find . -name "*.sh" -not -path "./.git/*" -exec sed -i 's/\borchestrator::rollback\s*()/rollback::orchestrator::full()/g' {} \;
find . -name "*.sh" -not -path "./.git/*" -exec sed -i 's/\borchestrator::immediate_rollback\b/rollback::orchestrator::immediate/g' {} \;
find . -name "*.sh" -not -path "./.git/*" -exec sed -i 's/\borchestrator::ssh_rollback\b/rollback::orchestrator::ssh/g' {} \;
find . -name "*.sh" -not -path "./.git/*" -exec sed -i 's/\borchestrator::ufw_rollback\b/rollback::orchestrator::ufw/g' {} \;
```

**Step 3: Run shellcheck on rollback.sh**

```bash
shellcheck -f gcc utils/rollback.sh 2>&1 | tee docs/plans/rollback_shellcheck_after.txt
```

Expected: No new warnings

**Step 4: Commit rollback renames**

```bash
git add utils/rollback.sh
git commit -m "refactor: rename rollback functions to rollback::orchestrator::action"
```

---

### Task 6: Update Orchestrator Calls in All Files

**Files:**
- Modify: `modules/04-ssh-port-modify.sh`
- Modify: `modules/05-ufw-modify.sh`
- Modify: `bsss-main.sh`

**Step 1: Update orchestrator::actions_after_port_change calls**

```bash
find . -name "*.sh" -not -path "./.git/*" -exec sed -i 's/\borchestrator::actions_after_port_change\b/ssh::orchestrator::actions_after_port_change/g' {} \;
```

**Step 2: Update orchestrator::actions_after_ufw_change calls**

```bash
find . -name "*.sh" -not -path "./.git/*" -exec sed -i 's/\borchestrator::actions_after_ufw_change\b/ufw::orchestrator::actions_after_ufw_change/g' {} \;
```

**Step 3: Update orchestrator::select_modify_module calls**

```bash
find . -name "*.sh" -not -path "./.git/*" -exec sed -i 's/\borchestrator::select_modify_module\b/runner::module::select_modify/g' {} \;
```

**Step 4: Run shellcheck on all modified files**

```bash
shellcheck -f gcc modules/*.sh lib/*.sh utils/*.sh bsss-main.sh 2>&1 | tee docs/plans/global_shellcheck_after.txt
```

Expected: No new warnings compared to baseline

**Step 5: Commit orchestrator call updates**

```bash
git add .
git commit -m "refactor: update all orchestrator function calls to new naming convention"
```

---

### Task 7: Rename Runner Functions

**Files:**
- Modify: `bsss-main.sh`

**Step 1: Rename function definitions**

```bash
sed -i 's/^run_modules_polling()/runner::module::run_check()/g' bsss-main.sh
sed -i 's/^run_modules_modify()/runner::module::run_modify()/g' bsss-main.sh
```

**Step 2: Update function calls**

```bash
sed -i 's/\brun_modules_polling\b/runner::module::run_check/g' bsss-main.sh
sed -i 's/\brun_modules_modify\b/runner::module::run_modify/g' bsss-main.sh
```

**Step 3: Run shellcheck**

```bash
shellcheck -f gcc bsss-main.sh 2>&1 | tee docs/plans/runner_shellcheck_after.txt
```

Expected: No new warnings

**Step 4: Commit runner renames**

```bash
git add bsss-main.sh
git commit -m "refactor: rename runner functions to runner::module::action"
```

---

### Task 8: Regenerate Function Map

**Files:**
- Modify: `function_map.txt`

**Step 1: Run function map generator**

```bash
./utils/generate_function_map.sh
```

Expected: function_map.txt updated with new function names

**Step 2: Verify map has no old function names**

```bash
grep -E "orchestrator::(actions_after_|dispatch_logic|bsss_config_|install_new_port_w_guard|watchdog_|stop_rollback|immediate_rollback|ssh_rollback|ufw_rollback|rollback|select_modify_module)" function_map.txt && echo "ERROR: Old names found!" || echo "OK: No old names"
grep -E "ssh::(install_new_port|get_user_choice|log_bsss_configs_w_port|log_other_configs_w_port|reset_and_pass|delete_all_bsss_rules|is_port_busy|generate_free_random_port|create_bsss_config_file|display_menu|apply_changes|wait_for_port_up|is_already_configured|force_service_mode)" function_map.txt && echo "ERROR: Old names found!" || echo "OK: No old names"
grep -E "ufw::(get_menu_items|display_menu|get_user_choice|execute_action|toggle|log_status|apply_changes|confirm_success|reset_and_pass|delete_all_bsss_rules|get_all_bsss_rules|get_all_rules|add_bsss_rule|is_active|force_disable|enable|log_active_ufw_rules)" function_map.txt | grep -v "ufw::ping" && echo "ERROR: Old names found!" || echo "OK: No old names"
```

Expected: "OK: No old names" for all checks

**Step 3: Commit updated function map**

```bash
git add function_map.txt
git commit -m "chore: regenerate function map after naming convention refactor"
```

---

### Task 9: Update AGENTS.md Documentation

**Files:**
- Modify: `AGENTS.md`

**Step 1: Read current AGENTS.md section 3**

```bash
grep -n "3. Архитектура ролей" AGENTS.md
```

Expected: Shows line number for section 3

**Step 2: Add naming convention section after section 12**

```bash
cat >> AGENTS.md << 'EOF'

13. Стандарт нейминга функций
 - Фундаментальные принципы:
   * Иерархия: domain::subdomain::action (максимум 3 уровня)
   * Субдомены обязательны для всех функций кроме самых простых
   * Читаемость превыше краткости

 - Правила для action:
   * Дублирование ДОПУСТИМО, если:
     - Без него теряется смысл: ssh::port::generate_free_random_port (не generate_free_random)
     - Повышает однозначность: ssh::port::is_port_busy (лучше чем is_busy)
     - Существительное — важная часть действия
   * Дублирование НЕ обязательно, если:
     - Субдомен уже однозначно указывает объект: ufw::ping::is_configured (не is_ping_configured)
     - Действие очевидно из контекста

 - Примеры нейминга:
   * Оркестраторы: ssh::orchestrator::actions_after_port_change, ufw::orchestrator::run_module
   * UI меню: ufw::menu::display, ufw::menu::get_user_choice
   * UI интерактивные: ssh::ui::get_new_port, ufw::ui::toggle
   * Проверки: ssh::port::is_port_busy, ssh::socket::is_configured
   * Генерация: ssh::port::generate_free_random_port, ssh::config::create_bsss_file
   * Удаление/сброс: ufw::rule::delete_all_bsss, ssh::rule::reset_and_pass
   * Системные: sys::file::validate_sshd_config, sys::service::restart
   * Запуск модулей: runner::module::run_check, runner::module::select_modify
   * Rollback: rollback::orchestrator::immediate, rollback::orchestrator::ssh

 - Домены и субдомены:
   * ufw: menu, ui, ping, rule
   * ssh: port, config, socket, ui
   * sys: file, service, process, update
   * io: confirm, input
   * log: border, message
   * orchestrator: только внутри домена (domain::orchestrator::action)
   * runner: module
   * rollback: orchestrator
EOF
```

**Step 3: Update examples in section 9**

```bash
# Read line numbers for section 9
sed -n '79,136p' AGENTS.md
```

Expected: Shows example section to update

**Step 4: Update examples with new naming**

```bash
# Update orchestrator example
sed -i 's/orchestrator::bsss_config_not_exists/ssh::orchestrator::config_not_exists/g' AGENTS.md

# Update filter example
sed -i 's/ufw::reset_and_pass/ufw::rule::reset_and_pass/g' AGENTS.md
sed -i 's/ufw::delete_all_bsss_rules/ufw::rule::delete_all_bsss/g' AGENTS.md

# Update source example
sed -i 's/ssh::generate_free_random_port/ssh::port::generate_free_random_port/g' AGENTS.md
sed -i 's/ssh::is_port_busy/ssh::port::is_port_busy/g' AGENTS.md
```

**Step 5: Commit AGENTS.md updates**

```bash
git add AGENTS.md
git commit -m "docs: add naming convention standard to AGENTS.md"
```

---

### Task 10: Final Verification

**Files:**
- Test: `function_map.txt`
- Test: All bash files

**Step 1: Verify no old function names remain**

```bash
# Check for old orchestrator names
echo "Checking for old orchestrator names..."
grep -rn "orchestrator::\(actions_after_port_change\|actions_after_ufw_change\|dispatch_logic\|bsss_config_\|install_new_port_w_guard\|watchdog_\|stop_rollback\|immediate_rollback\|ssh_rollback\|ufw_rollback\|rollback\|select_modify_module\)" --include="*.sh" . | grep -v "rollback::orchestrator" | grep -v "git log" && echo "ERROR!" || echo "OK"

# Check for old ssh names
echo "Checking for old ssh names..."
grep -rn "ssh::\(install_new_port\|get_user_choice\|log_bsss_configs_w_port\|log_other_configs_w_port\|reset_and_pass\|delete_all_bsss_rules\|is_port_busy\|generate_free_random_port\|create_bsss_config_file\|display_menu\|apply_changes\|wait_for_port_up\|is_already_configured\|force_service_mode\)" --include="*.sh" . | grep -v "git log" && echo "ERROR!" || echo "OK"

# Check for old ufw names (excluding ufw::ping which is correct)
echo "Checking for old ufw names..."
grep -rn "ufw::\(get_menu_items\|display_menu\|get_user_choice\|execute_action\|toggle\|log_status\|apply_changes\|confirm_success\|reset_and_pass\|delete_all_bsss_rules\|get_all_bsss_rules\|get_all_rules\|add_bsss_rule\|is_active\|force_disable\|enable\|log_active_ufw_rules\)" --include="*.sh" . | grep -v "git log" | grep -v "ufw::ping" | grep -v "ufw::rule" | grep -v "ufw::menu" | grep -v "ufw::ui" | grep -v "ufw::orchestrator" && echo "ERROR!" || echo "OK"
```

Expected: "OK" for all checks

**Step 2: Run full shellcheck**

```bash
shellcheck -f gcc modules/*.sh lib/*.sh utils/*.sh *.sh 2>&1 | tee docs/plans/final_shellcheck.txt
```

Expected: No new warnings compared to baseline (docs/plans/shellcheck_baseline.txt)

**Step 3: Verify all modules can be sourced**

```bash
for file in modules/*.sh lib/*.sh; do
    echo "Testing $file..."
    bash -n "$file" || echo "ERROR in $file"
done
```

Expected: No syntax errors

**Step 4: Generate final function map comparison**

```bash
git diff HEAD~10 function_map.txt | head -200
```

Expected: Shows renamed functions with old->new mapping

**Step 5: Commit final verification**

```bash
git add docs/plans/final_shellcheck.txt
git commit -m "chore: add final verification results for naming refactor"
```

---

### Task 11: Create Summary Documentation

**Files:**
- Create: `docs/plans/naming_refactor_summary.md`

**Step 1: Create summary document**

```bash
cat > docs/plans/naming_refactor_summary.md << 'EOF'
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
EOF
```

**Step 2: Commit summary**

```bash
git add docs/plans/naming_refactor_summary.md
git commit -m "docs: add naming refactor summary documentation"
```

---

### Task 12: Cleanup Temporary Files

**Files:**
- Delete: `docs/plans/function_renaming_map.txt`
- Delete: `docs/plans/*_shellcheck_after.txt`

**Step 1: Remove temporary verification files**

```bash
# Keep only final verification and summary
rm -f docs/plans/function_renaming_map.txt
rm -f docs/plans/ssh_shellcheck_after.txt
rm -f docs/plans/ufw_shellcheck_after.txt
rm -f docs/plans/update_shellcheck_after.txt
rm -f docs/plans/rollback_shellcheck_after.txt
rm -f docs/plans/runner_shellcheck_after.txt
rm -f docs/plans/global_shellcheck_after.txt
rm -f docs/plans/shellcheck_baseline.txt
```

**Step 2: Commit cleanup**

```bash
git add docs/plans/
git commit -m "chore: cleanup temporary verification files"
```

---

### Task 13: Final Merge Preparation

**Files:**
- Modify: None (git operations)

**Step 1: View all commits**

```bash
git log --oneline -15
```

Expected: Shows all refactor commits

**Step 2: Create comprehensive merge commit message**

```bash
cat > /tmp/naming_refactor_msg.txt << 'EOF'
refactor: unify function naming convention to domain::subdomain::action

Systematic refactoring of all function names to follow unified naming
convention with clear domain ownership and subdomain categorization.

Major changes:
- Introduced new domains: runner, rollback
- All orchestrators now use domain::orchestrator::* pattern
- SSH functions organized by subdomains: port, config, socket, ui
- UFW functions organized by subdomains: menu, ui, rule, ping
- System functions organized by subdomains: file, service, update
- UI functions separated: menu vs ui

Examples:
- ssh::install_new_port → ssh::port::install_new
- ufw::display_menu → ufw::menu::display
- orchestrator::rollback → rollback::orchestrator::full
- sys::restart_services → sys::service::restart

Naming rules:
- Maximum 3 levels: domain::subdomain::action
- Duplication allowed when it improves clarity
- Subdomains mandatory for proper categorization

Documentation:
- Added section 13 to AGENTS.md with full standard
- Updated all examples
- Created refactor summary in docs/plans/

Breaking: All function names changed. External scripts must update.

Verification:
- All old function names removed
- Shellcheck passes (no new warnings)
- All modules source successfully
EOF
```

**Step 3: Rebase into single commit (optional)**

```bash
# Interactive rebase to squash all refactor commits
git rebase -i HEAD~12
```

In the editor, mark all commits except first with `squash` or `s`.

**Step 4: Add commit message from file**

```bash
# If squashed, add the message
EDITOR='cat > /tmp/git_commit_msg.txt && echo ""' git commit --amend
cat /tmp/naming_refactor_msg.txt | git commit --amend -F -
```

**Step 5: Final verification**

```bash
git log --oneline -5
git diff --stat HEAD~1
```

Expected: One comprehensive commit with all changes

---

## Completion Checklist

- [ ] All function names follow domain::subdomain::action
- [ ] No old function names remain in codebase
- [ ] Shellcheck passes with no new warnings
- [ ] AGENTS.md updated with naming standard
- [ ] Function map regenerated and verified
- [ ] Summary documentation created
- [ ] All commits created with descriptive messages
- [ ] Temporary files cleaned up
- [ ] Final verification passed
