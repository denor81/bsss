# Common messages (English)

# Special message - pass through without translation
I18N_MESSAGES["no_translate"]="%s"
I18N_MESSAGES["common.pipefail.interrupted"]="Interrupted [RC: %d]"
I18N_MESSAGES["common.log_command"]="Command [%s]"

# Basic messages
I18N_MESSAGES["common.exit"]="%s. Exit"

# Error messages
I18N_MESSAGES["common.error_root_privileges"]="Root privileges or run with 'sudo' required. Running as regular user."
I18N_MESSAGES["common.error_invalid_input"]="Input error. Expected: %s"

# IO messages
I18N_MESSAGES["io.confirm_action.default_question"]="Continue?"
I18N_MESSAGES["io.confirm_action.run_setup"]="Run setup?"

# Info messages
I18N_MESSAGES["common.info_short_params"]="Available short parameters %s %s"
I18N_MESSAGES["common.default_actual_info"]="Information"

# Menu messages
I18N_MESSAGES["common.menu_header"]="Available actions:"
I18N_MESSAGES["common.menu_check"]="%s. System check"
I18N_MESSAGES["common.menu_language"]="%s. Язык • Language • 语言 • हिन्दी"

# Error messages - module runner
I18N_MESSAGES["common.error_no_modules_found"]="Cannot run, modules not found"
I18N_MESSAGES["common.error_module_error"]="Cannot run, one of the modules shows an error"
I18N_MESSAGES["common.error_no_modules_available"]="No modules available for setup"
I18N_MESSAGES["common.unexpected_error_module_failed_code"]="Unexpected error [RC: %s] [%s]"
I18N_MESSAGES["common.error_missing_meta_tags"]="Missing required meta tags MODULE_ORDER [RC: %s] [%s]"

# Info messages - module runner
I18N_MESSAGES["common.info_module_successful"]="Completed successfully"
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
I18N_MESSAGES["init.gawk.not_installed"]="gawk not installed"
I18N_MESSAGES["init.gawk.nul_explanation"]="gawk is required for associative arrays in Bash"
I18N_MESSAGES["init.gawk.install_confirm"]="Install gawk?"
I18N_MESSAGES["init.gawk.install_success"]="gawk installed successfully"
I18N_MESSAGES["init.gawk.install_error"]="Failed to install gawk"

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
