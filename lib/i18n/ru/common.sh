# Common messages (Russian)

# Error messages
I18N_MESSAGES["common.error_root_privileges"]="Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
I18N_MESSAGES["common.error_root_short"]="Требуются права root или запуск через 'sudo'"

# Info messages
I18N_MESSAGES["common.info_available_modules"]="Доступные модули настройки:"
I18N_MESSAGES["common.info_short_params"]="Доступны короткие параметры %s %s"
I18N_MESSAGES["common.info_start_module_runner"]="Запуск процедуры настройки Basic Server Security Setup (${UTIL_NAME^^}) - oneline запуск..."

# Success messages
I18N_MESSAGES["common.success_module_runner_started"]="Basic Server Security Setup (${UTIL_NAME^^}) - oneline запуск запущен"

# Menu messages
I18N_MESSAGES["common.menu_exit"]="Выход"
I18N_MESSAGES["common.menu_check"]="Проверка системы (check)"

# Error messages - param validation
I18N_MESSAGES["common.error_invalid_param"]="Некорректный параметр -%s, доступны: %s"
I18N_MESSAGES["common.error_param_requires_value"]="Параметр -%s требует значение"

# Error messages - module runner
I18N_MESSAGES["common.error_no_modules_found"]="Запуск не возможен, Модули не найдены"
I18N_MESSAGES["common.error_module_error"]="Запуск не возможен, один из модулей показывает ошибку"
I18N_MESSAGES["common.error_no_modules_available"]="Нет доступных модулей для настройки"
I18N_MESSAGES["common.error_module_failed_code"]="Ошибка в модуле [%s] [Code: %s]"
I18N_MESSAGES["common.error_missing_meta_tags"]="Отсутствуют обязательные метатеги MODULE_ORDER [Code: %s]"

# Info messages - module runner
I18N_MESSAGES["common.info_module_successful"]="Модуль успешно завершен [Code: %s]"
I18N_MESSAGES["common.info_module_user_cancelled"]="Модуль завершен пользователем [Code: %s]"
I18N_MESSAGES["common.info_module_rollback"]="Модуль завершен откатом [Code: %s]"
I18N_MESSAGES["common.info_module_requires_ssh"]="Модуль требует предварительной настройки SSH [Code: %s]"
I18N_MESSAGES["common.info_exit_menu"]="Выход из меню настройки"
I18N_MESSAGES["common.info_menu_item_format"]="%s. %s"
I18N_MESSAGES["common.info_menu_check_item"]="00. Проверка системы (check)"
