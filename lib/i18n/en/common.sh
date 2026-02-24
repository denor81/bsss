# Common messages (English)

I18N_MESSAGES["no_translate"]="%s"
I18N_MESSAGES["common.pipefail.interrupted"]="Interrupted [RC: %d]"
I18N_MESSAGES["common.log_command"]="Command [%s]"
I18N_MESSAGES["common.exit"]="Exit"

# Error messages
I18N_MESSAGES["common.error_root_privileges"]="Root privileges or run with 'sudo' required. Running as regular user."
I18N_MESSAGES["common.error_invalid_input"]="Input error. Expected: %s"

# IO messages
I18N_MESSAGES["io.confirm_action.default_question"]="Continue?"

# Info messages
I18N_MESSAGES["common.info_short_params"]="Available short parameters %s %s"
I18N_MESSAGES["common.default_actual_info"]="Information"

# Menu messages
I18N_MESSAGES["common.menu_header"]="Available actions:"
I18N_MESSAGES["common.menu_check"]="System check"
I18N_MESSAGES["common.menu_language"]="Язык • Language • 语言 • भाषा"

# Error messages - module runner
I18N_MESSAGES["common.error_module_error"]="Cannot run, one of the modules shows an error"
I18N_MESSAGES["common.error_no_modules_available"]="No modules available for setup"
I18N_MESSAGES["common.unexpected_error_module_failed_code"]="Unexpected error [RC: %s] [%s]"

# Info messages - module runner
I18N_MESSAGES["common.info_module_successful"]="Completed successfully [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_user_cancelled"]="Cancelled by user [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_rollback"]="Completed via rollback [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_requires"]="Pre-configuration required [RC: %s] [%s]"

# Info messages - uninstall
I18N_MESSAGES["common.info_uninstall_confirm"]="Uninstall ${UTIL_NAME^^}?"
I18N_MESSAGES["common.info_uninstall_start"]="Starting uninstallation of installed files..."
I18N_MESSAGES["common.info_uninstall_success"]="Uninstallation completed successfully"
I18N_MESSAGES["common.info_uninstall_path_not_exists"]="Path does not exist, skipping: %s"
I18N_MESSAGES["common.info_uninstall_delete"]="Deleting: %s"

# Error messages - uninstall
I18N_MESSAGES["common.error_uninstall_file_not_found"]="Uninstall paths file not found: %s"
I18N_MESSAGES["common.error_uninstall_delete_failed"]="Failed to delete: %s"

# Init messages
I18N_MESSAGES["init.bsss.full_name"]="Basic Server Security Setup"
I18N_MESSAGES["init.gawk.version"]="Critical dependencies:"
I18N_MESSAGES["init.gawk.installed"]="gawk installed [%s]"
I18N_MESSAGES["init.gawk.nul_explanation"]="gawk required for NUL delimiter (\0) support in data streams"

# Rollback messages
I18N_MESSAGES["rollback.exit_received"]="Received EXIT signal"
I18N_MESSAGES["rollback.close_redirection"]="Closed log redirection"
I18N_MESSAGES["rollback.stop_usr1_received"]="Received USR1 signal - stopping rollback timer"
I18N_MESSAGES["rollback.immediate_usr2_received"]="Received USR2 signal - stopping rollback timer and performing immediate rollback"
I18N_MESSAGES["rollback.ssh_dismantle"]="Full dismantling of ${UTIL_NAME^^} settings initiated..."
I18N_MESSAGES["rollback.system_restored"]="System restored to original state. Check system via 00"
I18N_MESSAGES["rollback.full_dismantle"]="Performing full rollback of all ${UTIL_NAME^^} settings..."
I18N_MESSAGES["rollback.ufw_dismantle"]="Performing UFW rollback..."
I18N_MESSAGES["rollback.ufw_disabled"]="UFW disabled. Check server access."
I18N_MESSAGES["rollback.permissions_dismantle"]="Performing permissions rules rollback..."
I18N_MESSAGES["rollback.permissions_restored"]="Permissions rules removed. Check server access."
I18N_MESSAGES["rollback.unknown_type"]="Unknown rollback type: %s"
I18N_MESSAGES["rollback.redirection_opened"]="Opened log redirection PID:%s>%s"
I18N_MESSAGES["rollback.timer_started"]="Background timer started for %s seconds..."
I18N_MESSAGES["rollback.timeout_ssh"]="On timeout, ${UTIL_NAME^^} SSH port settings will be reset and UFW disabled"
I18N_MESSAGES["rollback.timeout_ufw"]="On timeout, UFW will be disabled and all UFW settings will be reset"
I18N_MESSAGES["rollback.timeout_generic"]="On timeout, all ${UTIL_NAME^^} settings will be reset"
I18N_MESSAGES["rollback.timeout_permissions"]="On timeout, ${UTIL_NAME^^} access rules will be removed"
I18N_MESSAGES["rollback.timeout_reconnect"]="In case of current session loss, connect to server via old parameters after timeout"
I18N_MESSAGES["rollback.time_expired"]="Time expired - performing ROLLBACK"

# Module names
I18N_MESSAGES["module.system.update.name"]="System update"
I18N_MESSAGES["module.user.create.name"]="Create user"
I18N_MESSAGES["module.permissions.modify.name"]="Configure SSH access rights"
I18N_MESSAGES["module.ssh.name"]="SSH port configuration"
I18N_MESSAGES["module.ufw.name"]="UFW firewall configuration"
I18N_MESSAGES["module.full_rollback.name"]="Full rollback of all settings"
I18N_MESSAGES["module.auto.setup.name"]="Auto setup"

# IO ask_value
I18N_MESSAGES["io.ask_value.select_module"]="Select module"
I18N_MESSAGES["common.ask_select_action"]="Select item"
I18N_MESSAGES["common.confirm_connection"]="Confirm connection - enter %s or %s to cancel"
I18N_MESSAGES["common.success_changes_committed"]="Changes committed, Rollback disabled"

# Common warnings
I18N_MESSAGES["common.warning.dont_close_terminal"]="DO NOT CLOSE THIS TERMINAL WINDOW"

# Common install actions
I18N_MESSAGES["common.install.confirm"]="Install %s?"
I18N_MESSAGES["common.install.error"]="Error installing %s"
I18N_MESSAGES["common.install.success"]="%s installed successfully"
I18N_MESSAGES["common.install.not_installed"]="%s not installed"

# Common auth/check actions
I18N_MESSAGES["common.check_auth"]="Check ability to authenticate via login and password"
I18N_MESSAGES["common.copy_ssh_key"]="Copy SSH key to server for connection [ssh-copy-id]"

# Common action messages
I18N_MESSAGES["common.error.invalid_menu_id"]="Invalid action ID: [%s]"

# Delete messages (unified)
I18N_MESSAGES["common.delete.error"]="Error deleting: %s"
I18N_MESSAGES["common.delete.success"]="Deleted: %s"

# SSH messages

# Info messages
I18N_MESSAGES["ssh.info_rules_found"]="${UTIL_NAME^^} rules found for SSH:"
I18N_MESSAGES["ssh.info_no_rules"]="No ${UTIL_NAME^^} rules for SSH [%s]"

# Success messages
I18N_MESSAGES["ssh.success_port_up"]="SSH port %s successfully raised after %s attempts in %s sec"
I18N_MESSAGES["ssh.success_rule_created"]="${UTIL_NAME^^} rule created for SSH: [%s:%s]"

# Error messages
I18N_MESSAGES["ssh.error_port_busy"]="SSH port %s is already in use by another service."
I18N_MESSAGES["ssh.error_rule_creation_failed"]="Failed to create SSH rule: %s"
I18N_MESSAGES["ssh.error_config_sshd"]="SSH config error [sshd -t]"
I18N_MESSAGES["ssh.socket.unit_not_found"]="ssh.service unit not found in system"
I18N_MESSAGES["ssh.socket.script_purpose"]="This script switches SSH to service mode"

# Warning messages
I18N_MESSAGES["ssh.warning_external_rules_found"]="External SSH rules found:"
I18N_MESSAGES["ssh.warning_no_external_rules"]="No external SSH rules [%s]"

# Wait messages
I18N_MESSAGES["ssh.socket.wait_for_ssh_up.info"]="Waiting for SSH port %s to come up (timeout: %s sec)..."

# Menu items
I18N_MESSAGES["ssh.menu.item_reset"]="Reset (delete ${UTIL_NAME^^} rule)"
I18N_MESSAGES["ssh.menu.item_reinstall"]="Reinstall (replace with new port)"

# Input messages
I18N_MESSAGES["ssh.ui.get_new_port.prompt"]="Enter new SSH port or 0 for cancel"
I18N_MESSAGES["ssh.ui.get_new_port.hint_range"]="1-65535, Enter for %s"

# Service messages
I18N_MESSAGES["ssh.service.daemon_reloaded"]="Configuration reloaded [systemctl daemon-reload]"
I18N_MESSAGES["ssh.service.restarted"]="SSH service restarted [systemctl restart ssh.service]"

# Guard instructions
I18N_MESSAGES["ssh.guard.test_new"]="OPEN NEW WINDOW and test connection via port %s"

# Error messages
I18N_MESSAGES["ssh.error_port_not_up"]="PORT %s DID NOT COME UP [%s attempts in %s sec]"

# Socket check messages
I18N_MESSAGES["ssh.socket.configured"]="SSH works correctly in ssh.service mode"
I18N_MESSAGES["ssh.socket.mode_warning"]="SSH is running in socket-based activation mode, which may conflict with port changes via sshd_config"
I18N_MESSAGES["ssh.socket.mode_required"]="SSH needs to be switched to traditional service mode"
I18N_MESSAGES["ssh.socket.switch_confirm"]="Switch SSH to traditional service mode?"
I18N_MESSAGES["ssh.socket.socket_enabled"]="ssh.socket is enabled - SSH is running in socket-based activation mode"
I18N_MESSAGES["ssh.socket.socket_disabled"]="ssh.socket is disabled"
I18N_MESSAGES["ssh.socket.socket_status"]="ssh.socket status: %s"
I18N_MESSAGES["ssh.socket.not_found_traditional_mode"]="ssh.socket not found - SSH is running in traditional service mode (Ubuntu 20.04 or manually configured)"
I18N_MESSAGES["ssh.socket.force_mode"]="Switching SSH to traditional service mode"
I18N_MESSAGES["ssh.socket.service_not_active"]="SSH service is not active, starting..."
I18N_MESSAGES["ssh.socket.start_error"]="Failed to start SSH service"
I18N_MESSAGES["ssh.socket.active"]="SSH service is active in service mode"

# UFW messages (English)

# Error messages
I18N_MESSAGES["ufw.error.enable_failed"]="Error during activation [ufw --force enable]"

# Success messages
I18N_MESSAGES["ufw.success.backup_created"]="Backup created: [%s]"
I18N_MESSAGES["ufw.error.backup_failed"]="Failed to create backup %s [%s]"
I18N_MESSAGES["ufw.success.before_rules_edited"]="Ping rules edited: [%s]"
I18N_MESSAGES["ufw.success.reloaded"]="UFW reloaded [ufw reload]"
I18N_MESSAGES["ufw.success.enabled"]="UFW enabled"
I18N_MESSAGES["ufw.warning.continue_without_rules"]="Cannot continue: no ${UTIL_NAME^^} rules in UFW"
I18N_MESSAGES["ufw.warning.add_ssh_first"]="Add SSH port via SSH module first"
I18N_MESSAGES["ufw.rollback.test_access"]="Test server access after enabling UFW in new terminal window"

# Menu messages
I18N_MESSAGES["ufw.menu.item_disable"]="Disable UFW"
I18N_MESSAGES["ufw.menu.item_enable"]="Enable UFW"
I18N_MESSAGES["ufw.menu.item_ping_enable"]="Ping will be enabled [ACCEPT] [Default]"
I18N_MESSAGES["ufw.menu.item_ping_disable"]="Ping will be disabled [DROP]"

# Status messages
I18N_MESSAGES["ufw.status.enabled"]="UFW enabled"
I18N_MESSAGES["ufw.status.disabled"]="UFW disabled"
I18N_MESSAGES["ufw.status.ping_blocked"]="UFW ping blocked [DROP] [State: modified]"
I18N_MESSAGES["ufw.status.ping_allowed"]="UFW ping allowed [ACCEPT] [State: default]"

# Info messages
I18N_MESSAGES["ufw.info.no_rules_but_active"]="No ${UTIL_NAME^^} rules, but UFW is active - can be disabled"

# Success messages
I18N_MESSAGES["ufw.success.backup_restored"]="before.rules file restored: [%s]"

# Error messages
I18N_MESSAGES["ufw.error.restore_failed"]="Failed to restore %s from backup [%s]"
I18N_MESSAGES["ufw.error.edit_failed"]="Error during editing: [%s]"
I18N_MESSAGES["ufw.error.reload_failed"]="Failed to execute [ufw reload] [RC: %s]"

# System messages (English)

# Update module
I18N_MESSAGES["system.update.apt_not_found"]="Package manager apt-get not found"
I18N_MESSAGES["system.update.error"]="Error updating system packages"
I18N_MESSAGES["system.update.confirm"]="Update system packages? [apt-get update && apt-get upgrade -y]"

# Reload check module
I18N_MESSAGES["system.reload.not_required"]="Reboot not required"
I18N_MESSAGES["system.reload.reboot_required"]="System requires reboot %s"
I18N_MESSAGES["system.reload.pkgs_header"]="Packages requiring reboot:"

# Common helpers
I18N_MESSAGES["common.helpers.ssh.no_active_ports"]="No active SSH ports [ss -ltnp]"
I18N_MESSAGES["common.helpers.ssh.active_ports"]="Active SSH ports found [ss -ltnp]: %s"
I18N_MESSAGES["common.helpers.ufw.rules_found"]="UFW rules found [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules_not_found"]="No UFW rules [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules.sync"]="UFW rules synchronized with ${UTIL_NAME^^} settings for SSH port"
I18N_MESSAGES["common.helpers.ufw.rules.delete_warning"]="Deleting SSH rules will also delete related UFW rules"
I18N_MESSAGES["common.helpers.ufw.rule.deleted"]="Deleted UFW rule: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.delete_error"]="Error deleting UFW rule: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.added"]="Created UFW rule: [ufw allow %s/tcp comment '$BSSS_MARKER_COMMENT']"
I18N_MESSAGES["common.helpers.ufw.rule.add_error"]="Error adding UFW rule: [ufw allow %s/tcp comment ${UTIL_NAME^^}]"
I18N_MESSAGES["common.helpers.ufw.disabled"]="UFW: Fully deactivated [ufw --force disable]"
I18N_MESSAGES["common.helpers.ufw.error_interrupt"]="UFW error - possibly due to script emergency interruption [%s]"
I18N_MESSAGES["common.helpers.rollback.stop_signal"]="Sending rollback disable signal USR1 [PID: %s]"
I18N_MESSAGES["common.helpers.rollback.stop_received"]="Received USR1 signal - stopping script due to rollback"
I18N_MESSAGES["common.helpers.rollback.fifo_created"]="Created FIFO: %s"
I18N_MESSAGES["common.exit_received"]="Received EXIT signal [RC: %s]"
I18N_MESSAGES["common.int_received"]="Received INT signal [RC: %s]"

# UFW check
I18N_MESSAGES["ufw.check.installed_restart"]="UFW installed - restart the script"

# OS check
I18N_MESSAGES["os.check.file_not_found"]="File does not exist: %s"
I18N_MESSAGES["os.check.unsupported"]="System %s not supported (expected: %s)"
I18N_MESSAGES["os.check.supported"]="System %s supported"

# User create module
I18N_MESSAGES["user.check.user_count"]="Number of users (UID >= 1000): %s"
I18N_MESSAGES["user.check.only_root"]="Only root user exists in system"
I18N_MESSAGES["user.check.user_exists"]="User: %s"
I18N_MESSAGES["user.create.create_error"]="Error creating user"
I18N_MESSAGES["user.create.other_users_exist"]="Additional user already created"

# User create menu
I18N_MESSAGES["user.create.menu.header"]="What will happen:"
I18N_MESSAGES["user.create.menu.create_user"]="Creating: [useradd -m -d /home/%s -s /bin/bash -G sudo %s]"
I18N_MESSAGES["user.create.menu.generate_pass"]="Generating password: [openssl rand -base64 %s]"
I18N_MESSAGES["user.create.menu.create_sudoers"]="Creating rules in %s/%s"
I18N_MESSAGES["user.create.menu.password_once"]="Password will be shown only once on terminal screen (not logged)"
I18N_MESSAGES["user.create.menu.after_create"]="After creating user, copy your SSH key to server with ssh-copy-id command"
I18N_MESSAGES["user.create.menu.check_key"]="Test key-based authentication and if OK, disable password authentication and root access"
I18N_MESSAGES["user.create.menu.reminder"]="Reminder, how to delete user:"
I18N_MESSAGES["user.create.menu.reminder_deluser"]="deluser --remove-home --remove-all-files USERNAME # Delete user"
I18N_MESSAGES["user.create.menu.reminder_find"]="find / -uid USERID 2>/dev/null # Find all created files by id"
I18N_MESSAGES["user.create.menu.reminder_sudoers"]="grep -r -E 'USERNAME.*ALL' /etc/sudoers.d/ # Search user rules"
I18N_MESSAGES["user.create.menu.reminder_pgrep"]="pgrep -u USERNAME # view process PIDs"
I18N_MESSAGES["user.create.menu.reminder_killall"]="killall -9 -u USERNAME # terminate all processes"
I18N_MESSAGES["user.create.menu.item_create"]="Create user"
I18N_MESSAGES["user.create.menu.user_created"]="User %s created, password assigned"
I18N_MESSAGES["user.create.menu.password_no_log"]="Not logged >>>[%s]<<<"
I18N_MESSAGES["user.create.menu.after_copy_key"]="After copying SSH key and successful connection, you can disable password authentication"

# Permissions messages
I18N_MESSAGES["permissions.menu.item_create"]="Create ${UTIL_NAME^^} access rules"
I18N_MESSAGES["permissions.menu.item_remove"]="Remove ${UTIL_NAME^^} access rules"
I18N_MESSAGES["permissions.info.create_rules"]="File with rules will be created in directory %s"
I18N_MESSAGES["permissions.guard.test_access"]="Test server access in new terminal window"

# Permissions check
I18N_MESSAGES["permissions.check.current_ssh_config"]="Current SSH configuration [sshd -T]:"

# Permissions warnings
I18N_MESSAGES["permissions.attention.password_connection"]="Password connection detected. In automatic mode, rules are created that prohibit password authorization. Connect as a sudo user (not root) using an SSH key."
I18N_MESSAGES["permissions.info.session_owner_conn_type"]="Session owner: %s [connection type: %s]"
I18N_MESSAGES["permissions.warn.root_auth"]="Log in as a sudo-user by ssh-key (not root, not pass). Current authorization: %s"
I18N_MESSAGES["permissions.warn.session_timeout_limitations"]="Session longer than 72 hours [cannot determine connection type - log limitations]"
I18N_MESSAGES["permissions.warn.reconnect_new_window"]="Reconnect in new terminal window [%s]"
I18N_MESSAGES["permissions.warn.cannot_determine_connection"]="Failed to determine connection type"

# Permissions confirm
I18N_MESSAGES["permissions.confirm.reset_rules"]="Execute reset of ${UTIL_NAME^^} access rules?"

# Permissions info
I18N_MESSAGES["permissions.info.only_reset_available"]="In this mode only reset is possible"

# Common unified messages (reusable across modules)
I18N_MESSAGES["common.info.rules_found"]="${UTIL_NAME^^} access rules found:"
I18N_MESSAGES["common.info.no_rules"]="No ${UTIL_NAME^^} access rules [/etc/ssh/sshd_config]"
I18N_MESSAGES["common.info.external_rules_found"]="External access rules found"
I18N_MESSAGES["common.info.no_external_rules"]="No external access rules [/etc/ssh/sshd_config]"
I18N_MESSAGES["common.file.created"]="File created: %s"
I18N_MESSAGES["common.error.create_file"]="Error creating file: %s"
I18N_MESSAGES["common.info.users_in_system"]="Users in system:"
I18N_MESSAGES["common.error.check_users"]="Error checking user composition"
I18N_MESSAGES["common.session.owner"]="Session owner"

# Rollback error messages
I18N_MESSAGES["rollback.error.rollback_errors"]="Errors during rollback: %s"

# Full rollback info
I18N_MESSAGES["full_rollback.info.full_rollback_warning"]="Full rollback of all ${UTIL_NAME^^} settings will be performed"

# Permissions session info

# Auto setup info
I18N_MESSAGES["auto.info.auto_setup_rules"]="Automatic installation of basic rules will be performed:"
I18N_MESSAGES["auto.info.sshd_random_port"]="SSHD Random SSH port installed [10000-65535]"
I18N_MESSAGES["auto.info.sshd_deny_root"]="SSHD Deny root user authentication"
I18N_MESSAGES["auto.info.sshd_deny_password"]="SSHD Deny password authentication"
I18N_MESSAGES["auto.info.ufw_disable_ping"]="UFW Server ping disabled [/etc/ufw/before.rules]"
I18N_MESSAGES["auto.info.ufw_ssh_port_rule"]="UFW Rule created for newly installed SSH port"
I18N_MESSAGES["auto.info.ufw_activation"]="UFW Activation"
I18N_MESSAGES["auto.info.rollback_timer_activation"]="Background process rollback.sh will be activated for rollback after %s seconds. If it is impossible to connect to the server, rollback the changes in the current session or wait for the timer to expire and connect to the server using the old data."
I18N_MESSAGES["auto.info.logs_location"]="To view logs, use the system log [journalctl -t ${UTIL_NAME} --since \"10 minutes ago\"] or logs in the installation directory %s"
I18N_MESSAGES["auto.info.connect_instruction"]="Open a new terminal and connect via SSH key on port %s. If you cannot connect, enter 0 to rollback changes or confirm successful connection to commit settings"

# UFW activation
I18N_MESSAGES["ufw.success.enabled"]="UFW successfully enabled [ufw --force enable]"

# Rollback signal messages
I18N_MESSAGES["rollback.signal_usr1_sent"]="Sent USR1 signal"
I18N_MESSAGES["rollback.signal_usr2_sent"]="Sent USR2 signal"
I18N_MESSAGES["rollback.fifo_created"]="Created FIFO:%s"
I18N_MESSAGES["rollback.waiting_ready"]="Waiting for rollback.sh to be ready..."
I18N_MESSAGES["rollback.ready_received"]="Received READY from %s"
