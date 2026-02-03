# Common messages (English)
declare -gA I18N_MESSAGES

# Error messages
I18N_MESSAGES["common.error_root_privileges"]="Root privileges or run with 'sudo' required. Running as regular user."
I18N_MESSAGES["common.error_root_short"]="Root privileges or run with 'sudo' required"

# Info messages
I18N_MESSAGES["common.info_available_modules"]="Available setup modules:"
I18N_MESSAGES["common.info_short_params"]="Available short parameters %s %s"
I18N_MESSAGES["common.info_start_module_runner"]="Starting Basic Server Security Setup (${UTIL_NAME^^}) - oneline runner..."

# Success messages
I18N_MESSAGES["common.success_module_runner_started"]="Basic Server Security Setup (${UTIL_NAME^^}) - oneline runner started"

# Menu messages
I18N_MESSAGES["common.menu_exit"]="Exit"
I18N_MESSAGES["common.menu_check"]="System check (check)"

# Error messages - param validation
I18N_MESSAGES["common.error_invalid_param"]="Invalid parameter -%s, available: %s"
I18N_MESSAGES["common.error_param_requires_value"]="Parameter -%s requires a value"

# Error messages - module runner
I18N_MESSAGES["common.error_no_modules_found"]="Cannot run, modules not found"
I18N_MESSAGES["common.error_module_error"]="Cannot run, one of the modules shows an error"
I18N_MESSAGES["common.error_no_modules_available"]="No modules available for setup"
I18N_MESSAGES["common.error_module_failed_code"]="Error in module [%s] [Code: %s]"
I18N_MESSAGES["common.error_missing_meta_tags"]="Missing required meta tags MODULE_ORDER [Code: %s]"

# Info messages - module runner
I18N_MESSAGES["common.info_module_successful"]="Module completed successfully [Code: %s]"
I18N_MESSAGES["common.info_module_user_cancelled"]="Module cancelled by user [Code: %s]"
I18N_MESSAGES["common.info_module_rollback"]="Module completed via rollback [Code: %s]"
I18N_MESSAGES["common.info_module_requires_ssh"]="Module requires preliminary SSH setup [Code: %s]"
I18N_MESSAGES["common.info_exit_menu"]="Exit setup menu"
I18N_MESSAGES["common.info_menu_item_format"]="%s. %s"
I18N_MESSAGES["common.info_menu_check_item"]="00. System check (check)"
