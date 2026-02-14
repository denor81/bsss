# Common messages (Russian)

I18N_MESSAGES["no_translate"]="%s"
I18N_MESSAGES["common.pipefail.interrupted"]="Прервано [RC: %d]"
I18N_MESSAGES["common.log_command"]="Команда [%s]"
I18N_MESSAGES["common.exit"]="Выход"

# Error messages
I18N_MESSAGES["common.error_root_privileges"]="Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
I18N_MESSAGES["common.error_invalid_input"]="Ошибка ввода. Ожидается: %s"

# IO messages
I18N_MESSAGES["io.confirm_action.default_question"]="Продолжить?"
I18N_MESSAGES["io.confirm_action.run_setup"]="Запустить настройку?"

# Info messages
I18N_MESSAGES["common.info_short_params"]="Доступны короткие параметры %s %s"
I18N_MESSAGES["common.default_actual_info"]="Информация"

# Menu messages
I18N_MESSAGES["common.menu_header"]="Доступные действия:"
I18N_MESSAGES["common.menu_check"]="%s. Проверка системы"
I18N_MESSAGES["common.menu_language"]="%s. Язык • Language • 语言 • हिन्दी"

# Error messages - module runner
I18N_MESSAGES["common.error_no_modules_found"]="Запуск не возможен, Модули не найдены"
I18N_MESSAGES["common.error_module_error"]="Запуск не возможен, один из модулей показывает ошибку"
I18N_MESSAGES["common.error_no_modules_available"]="Нет доступных модулей для настройки"
I18N_MESSAGES["common.unexpected_error_module_failed_code"]="Непредвиденная ошибка [RC: %s] [%s]"
I18N_MESSAGES["common.error_missing_meta_tags"]="Отсутствуют обязательные метатеги MODULE_ORDER [RC: %s] [%s]"

# Info messages - module runner
I18N_MESSAGES["common.info_module_successful"]="Успешно завершен [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_user_cancelled"]="Завершено пользователем [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_rollback"]="Завершен откатом [RC: %s] [%s]"
I18N_MESSAGES["common.info_module_requires"]="Требуется предварительная настройка [RC: %s] [%s]"
I18N_MESSAGES["common.info_menu_item_format"]="%s. %s"

# Info messages - uninstall
I18N_MESSAGES["common.info_uninstall_confirm"]="Удалить ${UTIL_NAME^^}?"
I18N_MESSAGES["common.info_uninstall_start"]="Начинаю удаление установленных файлов..."
I18N_MESSAGES["common.info_uninstall_success"]="Удаление завершено успешно"
I18N_MESSAGES["common.info_uninstall_path_not_exists"]="Путь не существует, пропускаю: %s"
I18N_MESSAGES["common.info_uninstall_delete"]="Удаляю: %s"

# Error messages - uninstall
I18N_MESSAGES["common.error_uninstall_file_not_found"]="Файл с путями для удаления не найден: %s"
I18N_MESSAGES["common.error_uninstall_delete_failed"]="Не удалось удалить: %s"

# Init messages
I18N_MESSAGES["init.gawk.version"]="Ключевые зависимости:"
I18N_MESSAGES["init.gawk.installed"]="gawk установлен [%s]"
I18N_MESSAGES["init.gawk.not_installed"]="gawk не установлен"
I18N_MESSAGES["init.gawk.nul_explanation"]="gawk требуется для работы ассоциативных массивов в Bash"
I18N_MESSAGES["init.gawk.install_confirm"]="Установить gawk?"
I18N_MESSAGES["init.gawk.install_success"]="gawk успешно установлен"
I18N_MESSAGES["init.gawk.install_error"]="Ошибка установки gawk"

# Rollback messages
I18N_MESSAGES["rollback.exit_received"]="Получен сигнал EXIT"
I18N_MESSAGES["rollback.close_redirection"]="Закрываем перенаправление 2>FIFO>parent_script"
I18N_MESSAGES["rollback.stop_usr1_received"]="Получен сигнал USR1 - остановка таймера отката"
I18N_MESSAGES["rollback.immediate_usr2_received"]="Получен сигнал USR2 - остановка таймера отката и немедленный откат изменений"
I18N_MESSAGES["rollback.send_signal_to_parent"]="Посылаем сигнал отката основному скрипту USR1 [PID: %s]"
I18N_MESSAGES["rollback.full_dismantle"]="Инициирован полный демонтаж настроек ${UTIL_NAME^^}..."
I18N_MESSAGES["rollback.system_restored"]="Система возвращена к исходному состоянию. Проверьте доступ по старым портам."
I18N_MESSAGES["rollback.ufw_executing"]="Выполняется откат UFW..."
I18N_MESSAGES["rollback.ufw_disabled"]="UFW отключен. Проверьте доступ к серверу."
I18N_MESSAGES["rollback.permissions_executing"]="Выполняется откат правил permissions..."
I18N_MESSAGES["rollback.permissions_restored"]="Правила permissions удалены. Проверьте доступ к серверу."
I18N_MESSAGES["rollback.unknown_type"]="Неизвестный тип отката: %s"
I18N_MESSAGES["rollback.redirection_opened"]="Открыто перенаправление 2>FIFO>parent_script"
I18N_MESSAGES["rollback.timer_started"]="Фоновый таймер запущен на %s сек..."
I18N_MESSAGES["rollback.timeout_ssh"]="По истечению таймера будут сброшены настройки ${UTIL_NAME^^} для SSH порта и отключен UFW"
I18N_MESSAGES["rollback.timeout_ufw"]="По истечению таймера будет отключен UFW"
I18N_MESSAGES["rollback.timeout_generic"]="По истечению таймера будут сброшены настройки"
I18N_MESSAGES["rollback.timeout_reconnect"]="В случае разрыва текущей сессии подключайтесь к серверу по старым параметрам после истечения таймера"
I18N_MESSAGES["rollback.time_expired"]="Время истекло - выполняется ОТКАТ"

# Module names
I18N_MESSAGES["module.system.update.name"]="Обновление системы"
I18N_MESSAGES["module.user.create.name"]="Создание пользователя"
I18N_MESSAGES["module.permissions.check.name"]="Проверка прав доступа SSH"
I18N_MESSAGES["module.permissions.modify.name"]="Настройка прав доступа SSH"
I18N_MESSAGES["module.ssh.name"]="Настройка SSH порта"
I18N_MESSAGES["module.ufw.name"]="Настройка брандмауэра UFW"

# IO ask_value
I18N_MESSAGES["io.ask_value.select_module"]="Выберите модуль"
