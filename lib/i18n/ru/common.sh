# Common messages (Russian)
declare -gA COMMON_MESSAGES

# Error messages
COMMON_MESSAGES["error_root_privileges"]="Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
COMMON_MESSAGES["error_root_short"]="Требуются права root или запуск через 'sudo'"

# Info messages
COMMON_MESSAGES["info_available_modules"]="Доступные модули настройки:"
COMMON_MESSAGES["info_short_params"]="Доступны короткие параметры %s %s"
COMMON_MESSAGES["info_start_module_runner"]="Запуск процедуры настройки Basic Server Security Setup (${UTIL_NAME^^}) - oneline запуск..."

# Success messages
COMMON_MESSAGES["success_module_runner_started"]="Basic Server Security Setup (${UTIL_NAME^^}) - oneline запуск запущен"

# Menu messages
COMMON_MESSAGES["menu_exit"]="Выход"
COMMON_MESSAGES["menu_check"]="Проверка системы (check)"
