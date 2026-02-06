# Critical messages (English)

I18N_MESSAGES["no_translate"]="%s"

# Exit signals
I18N_MESSAGES["common.helpers.rollback.exit_received"]="Received EXIT signal [RC: %s]"
I18N_MESSAGES["common.helpers.rollback.int_received"]="Received INT signal [RC: %s]"

# Error messages
I18N_MESSAGES["common.error_root_privileges"]="Root privileges or run with 'sudo' required. Running as regular user."
I18N_MESSAGES["common.error_root_short"]="Root privileges or run with 'sudo' required"
I18N_MESSAGES["common.error_invalid_input"]="Input error. Expected: %s"

# Info messages
I18N_MESSAGES["common.info_available_modules"]="Available setup modules:"
I18N_MESSAGES["common.info_short_params"]="Available short parameters %s %s"
I18N_MESSAGES["common.info_start_module_runner"]="Starting Basic Server Security Setup (${UTIL_NAME^^}) - oneline runner..."
I18N_MESSAGES["common.default_actual_info"]="Information"

# IO messages
I18N_MESSAGES["io.confirm_action.default_question"]="Continue?"
I18N_MESSAGES["io.confirm_action.run_setup"]="Run setup?"

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