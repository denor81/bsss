# Common messages (English)
declare -gA COMMON_MESSAGES

# Error messages
COMMON_MESSAGES["error_root_privileges"]="Root privileges or run with 'sudo' required. Running as regular user."
COMMON_MESSAGES["error_root_short"]="Root privileges or run with 'sudo' required"

# Info messages
COMMON_MESSAGES["info_available_modules"]="Available setup modules:"
COMMON_MESSAGES["info_short_params"]="Available short parameters %s %s"
COMMON_MESSAGES["info_start_module_runner"]="Starting Basic Server Security Setup (${UTIL_NAME^^}) - oneline runner..."

# Success messages
COMMON_MESSAGES["success_module_runner_started"]="Basic Server Security Setup (${UTIL_NAME^^}) - oneline runner started"

# Menu messages
COMMON_MESSAGES["menu_exit"]="Exit"
COMMON_MESSAGES["menu_check"]="System check (check)"
