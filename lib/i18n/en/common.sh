# Common messages (English)

# Special message - pass through without translation
I18N_MESSAGES["no_translate"]="%s"
I18N_MESSAGES["common.pipefail.interrupted"]="Interrupted [RC: %d]"
I18N_MESSAGES["common.log_command"]="Command [%s]"

# Basic messages
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
I18N_MESSAGES["common.menu_language"]="Язык • Language • 语言 • हिन्दी"

# Error messages - module runner
I18N_MESSAGES["common.error_no_modules_found"]="Cannot run, modules not found"
I18N_MESSAGES["common.error_module_error"]="Cannot run, one of the modules shows an error"
I18N_MESSAGES["common.error_no_modules_available"]="No modules available for setup"
I18N_MESSAGES["common.unexpected_error_module_failed_code"]="Unexpected error [RC: %s] [%s]"
I18N_MESSAGES["common.error_missing_meta_tags"]="Missing required meta tags MODULE_ORDER [RC: %s] [%s]"

# Info messages - module runner
I18N_MESSAGES["common.info_module_successful"]="Completed successfully [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_user_cancelled"]="Cancelled by user [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_rollback"]="Completed via rollback [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_requires"]="Pre-configuration required [RC: %s] [%s]"
I18N_MESSAGES["common.info_menu_item_format"]="%s. %s"

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
I18N_MESSAGES["init.gawk.version"]="Critical dependencies:"
I18N_MESSAGES["init.gawk.installed"]="gawk installed [%s]"

# Rollback messages
I18N_MESSAGES["rollback.exit_received"]="Received EXIT signal"
I18N_MESSAGES["rollback.close_redirection"]="Closing redirection 2>FIFO>parent_script"
I18N_MESSAGES["rollback.stop_usr1_received"]="Received USR1 signal - stopping rollback timer"
I18N_MESSAGES["rollback.immediate_usr2_received"]="Received USR2 signal - stopping rollback timer and performing immediate rollback"
I18N_MESSAGES["rollback.send_signal_to_parent"]="Sending rollback signal to main script USR1 [PID: %s]"
I18N_MESSAGES["rollback.full_dismantle"]="Full dismantling of ${UTIL_NAME^^} settings initiated..."
I18N_MESSAGES["rollback.system_restored"]="System restored to original state. Check access via old ports."
I18N_MESSAGES["rollback.ufw_executing"]="Performing UFW rollback..."
I18N_MESSAGES["rollback.ufw_disabled"]="UFW disabled. Check server access."
I18N_MESSAGES["rollback.unknown_type"]="Unknown rollback type: %s"
I18N_MESSAGES["rollback.redirection_opened"]="Opened redirection 2>FIFO>parent_script"
I18N_MESSAGES["rollback.timer_started"]="Background timer started for %s seconds..."
I18N_MESSAGES["rollback.timeout_ssh"]="On timeout, ${UTIL_NAME^^} SSH port settings will be reset and UFW disabled"
I18N_MESSAGES["rollback.timeout_ufw"]="On timeout, UFW will be disabled"
I18N_MESSAGES["rollback.timeout_generic"]="On timeout, settings will be reset"
I18N_MESSAGES["rollback.timeout_reconnect"]="In case of current session loss, connect to server via old parameters after timeout"
I18N_MESSAGES["rollback.time_expired"]="Time expired - performing ROLLBACK"

# Module names
I18N_MESSAGES["module.system.update.name"]="System update"
I18N_MESSAGES["module.ssh.name"]="SSH port configuration"
I18N_MESSAGES["module.ufw.name"]="UFW firewall configuration"

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

# SSH port messages (English)

# Menu UI

# Input prompts

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
I18N_MESSAGES["ssh.menu.item_reset"]="Reset (delete %s rule)"
I18N_MESSAGES["ssh.menu.item_reinstall"]="Reinstall (replace with new port)"

# Input messages
I18N_MESSAGES["ssh.ui.get_new_port.prompt"]="Enter new SSH port"
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
I18N_MESSAGES["common.helpers.validate_order.error_missing_tag"]="Missing required MODULE_ORDER tag: %s"
I18N_MESSAGES["common.helpers.validate_order.error_duplicate"]="Duplicate MODULE_ORDER (%s): %s"
I18N_MESSAGES["common.delete.error"]="Error deleting: %s"
I18N_MESSAGES["common.delete.success"]="Deleted: %s"
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
I18N_MESSAGES["common.helpers.ufw.already_disabled"]="UFW: deactivated"
I18N_MESSAGES["common.helpers.rollback.stop_signal"]="Sending rollback disable signal USR1 [PID: %s]"
I18N_MESSAGES["common.helpers.rollback.stop_received"]="Received USR1 signal - stopping script due to rollback"
I18N_MESSAGES["common.helpers.rollback.fifo_created"]="Created FIFO: %s"

# Exit signals
I18N_MESSAGES["common.helpers.rollback.exit_received"]="Received EXIT signal [RC: %s]"
I18N_MESSAGES["common.helpers.rollback.int_received"]="Received INT signal [RC: %s]"

# Init helpers

# UFW check
I18N_MESSAGES["ufw.check.installed_restart"]="UFW installed - restart the script"

# OS check
I18N_MESSAGES["os.check.file_not_found"]="File does not exist: %s"
I18N_MESSAGES["os.check.unsupported"]="System %s not supported (expected: %s)"
I18N_MESSAGES["os.check.supported"]="System %s supported"
