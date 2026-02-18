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

# Info messages
I18N_MESSAGES["common.info_short_params"]="Доступны короткие параметры %s %s"
I18N_MESSAGES["common.default_actual_info"]="Информация"

# Menu messages
I18N_MESSAGES["common.menu_header"]="Доступные действия:"
I18N_MESSAGES["common.menu_check"]="Проверка системы"
I18N_MESSAGES["common.menu_language"]="Язык • Language • 语言 • हिन्दी"

# Error messages - module runner
I18N_MESSAGES["common.error_no_modules_found"]="Запуск не возможен, Модули не найдены"
I18N_MESSAGES["common.error_module_error"]="Запуск не возможен, один из модулей показывает ошибку"
I18N_MESSAGES["common.error_no_modules_available"]="Нет доступных модулей для настройки"
I18N_MESSAGES["common.unexpected_error_module_failed_code"]="Непредвиденная ошибка [RC: %s] [%s]"

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
I18N_MESSAGES["init.gawk.nul_explanation"]="Требуется gawk для поддержки NUL-разделителей (\0) в потоках данных"

# Rollback messages
I18N_MESSAGES["rollback.exit_received"]="Получен сигнал EXIT"
I18N_MESSAGES["rollback.close_redirection"]="Закрываем перенаправление 2>FIFO>parent_script"
I18N_MESSAGES["rollback.stop_usr1_received"]="Получен сигнал USR1 - остановка таймера отката"
I18N_MESSAGES["rollback.immediate_usr2_received"]="Получен сигнал USR2 - остановка таймера отката и немедленный откат изменений"
I18N_MESSAGES["rollback.send_signal_to_parent"]="Посылаем сигнал отката основному скрипту USR1 [PID: %s]"
I18N_MESSAGES["rollback.ssh_dismantle"]="Инициирован полный демонтаж настроек ${UTIL_NAME^^}..."
I18N_MESSAGES["rollback.system_restored"]="Система возвращена к исходному состоянию. Проверьте доступ по старым портам."
I18N_MESSAGES["rollback.full_dismantle"]="Выполняется полный откат всех настроек BSSS..."
I18N_MESSAGES["rollback.ufw_dismantle"]="Выполняется откат UFW..."
I18N_MESSAGES["rollback.ufw_disabled"]="UFW отключен. Проверьте доступ к серверу."
I18N_MESSAGES["rollback.permissions_dismantle"]="Выполняется откат правил permissions..."
I18N_MESSAGES["rollback.permissions_restored"]="Правила permissions удалены. Проверьте доступ к серверу."
I18N_MESSAGES["rollback.unknown_type"]="Неизвестный тип отката: %s"
I18N_MESSAGES["rollback.redirection_opened"]="Открыто перенаправление 2>FIFO>parent_script"
I18N_MESSAGES["rollback.timer_started"]="Фоновый таймер запущен на %s сек..."
I18N_MESSAGES["rollback.timeout_ssh"]="По истечению таймера будут сброшены настройки ${UTIL_NAME^^} для SSH порта и отключен UFW"
I18N_MESSAGES["rollback.timeout_ufw"]="По истечению таймера будет отключен UFW"
I18N_MESSAGES["rollback.timeout_permissions"]="По истечению таймера будут удалены правила ${UTIL_NAME^^} для доступа"
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
I18N_MESSAGES["module.full_rollback.name"]="Полный откат всех настроек"
I18N_MESSAGES["module.auto.setup.name"]="Автоматическая настройка"

# IO ask_value
I18N_MESSAGES["io.ask_value.select_module"]="Выберите модуль"
I18N_MESSAGES["common.ask_select_action"]="Выберите пункт"
I18N_MESSAGES["common.confirm_connection"]="Подтвердите подключение - введите %s или %s для отмены"
I18N_MESSAGES["common.success_changes_committed"]="Изменения зафиксированы, Rollback отключен"

# Common warnings
I18N_MESSAGES["common.warning.dont_close_terminal"]="НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"

# Common install actions
I18N_MESSAGES["common.install.confirm"]="Установить %s?"
I18N_MESSAGES["common.install.error"]="Ошибка установки %s"
I18N_MESSAGES["common.install.success"]="%s успешно установлен"
I18N_MESSAGES["common.install.not_installed"]="%s не установлен"

# Common auth/check actions
I18N_MESSAGES["common.check_auth"]="Проверьте возможность авторизации по логину и паролю"
I18N_MESSAGES["common.copy_ssh_key"]="Скопируйте на сервер ключ для подключения по SSH [ssh-copy-id]"

# Common action messages
I18N_MESSAGES["common.error.invalid_menu_id"]="Неверный ID действия: [%s]"

# Delete messages (unified)
I18N_MESSAGES["common.delete.error"]="Ошибка при удалении: %s"
I18N_MESSAGES["common.delete.success"]="Удалено: %s"

# SSH messages

# Info messages
I18N_MESSAGES["ssh.info_rules_found"]="Есть правила ${UTIL_NAME^^} для SSH:"
I18N_MESSAGES["ssh.info_no_rules"]="Нет правил ${UTIL_NAME^^} для SSH [%s]"

# Success messages
I18N_MESSAGES["ssh.success_port_up"]="SSH порт %s успешно поднят после %s попыток в течение %s сек"
I18N_MESSAGES["ssh.success_rule_created"]="Создано правило ${UTIL_NAME^^} для SSH: [%s:%s]"

# Error messages
I18N_MESSAGES["ssh.error_port_busy"]="SSH порт %s уже занят другим сервисом."
I18N_MESSAGES["ssh.error_rule_creation_failed"]="Не удалось создать правило SSH: %s"
I18N_MESSAGES["ssh.error_config_sshd"]="Ошибка конфигурации ssh [sshd -t]"
I18N_MESSAGES["ssh.socket.unit_not_found"]="Юнит ssh.service не найден в системе"
I18N_MESSAGES["ssh.socket.script_purpose"]="Этот скрипт переключает SSH в режим service"

# Warning messages
I18N_MESSAGES["ssh.warning_external_rules_found"]="Есть сторонние правила SSH:"
I18N_MESSAGES["ssh.warning_no_external_rules"]="Нет сторонних правил SSH [%s]"

# Wait messages
I18N_MESSAGES["ssh.socket.wait_for_ssh_up.info"]="Ожидание поднятия SSH порта %s (таймаут: %s сек)..."

# Menu items
I18N_MESSAGES["ssh.menu.item_reset"]="Сброс (удаление правила %s)"
I18N_MESSAGES["ssh.menu.item_reinstall"]="Переустановка (замена на новый порт)"

# Input messages
I18N_MESSAGES["ssh.ui.get_new_port.prompt"]="Введите новый SSH порт или 0 для отмены"
I18N_MESSAGES["ssh.ui.get_new_port.hint_range"]="1-65535, Enter для %s"

# Service messages
I18N_MESSAGES["ssh.service.daemon_reloaded"]="Конфигурация перезагружена [systemctl daemon-reload]"
I18N_MESSAGES["ssh.service.restarted"]="SSH сервис перезагружен [systemctl restart ssh.service]"

# Guard instructions
I18N_MESSAGES["ssh.guard.test_new"]="ОТКРОЙТЕ НОВОЕ ОКНО и проверьте связь через порт %s"

# Error messages
I18N_MESSAGES["ssh.error_port_not_up"]="ПОРТ %s НЕ ПОДНЯЛСЯ [%s попыток в течение %s сек]"

# Socket check messages
I18N_MESSAGES["ssh.socket.configured"]="SSH корректно работает в режиме ssh.service"
I18N_MESSAGES["ssh.socket.mode_warning"]="SSH работает в socket-based activation mode, что может конфликтовать с изменением порта через sshd_config"
I18N_MESSAGES["ssh.socket.mode_required"]="Требуется переключение SSH в традиционный service mode"
I18N_MESSAGES["ssh.socket.switch_confirm"]="Переключить SSH в традиционный service mode?"
I18N_MESSAGES["ssh.socket.socket_enabled"]="ssh.socket активен - SSH работает в socket-based activation mode"
I18N_MESSAGES["ssh.socket.socket_disabled"]="ssh.socket отключен"
I18N_MESSAGES["ssh.socket.socket_status"]="Статус ssh.socket: %s"
I18N_MESSAGES["ssh.socket.not_found_traditional_mode"]="ssh.socket не найден - SSH работает в традиционном service mode (Ubuntu 20.04 или сконфигурирован вручную)"
I18N_MESSAGES["ssh.socket.force_mode"]="Переключение SSH в традиционный service mode"
I18N_MESSAGES["ssh.socket.service_not_active"]="SSH сервис не активен, запускаем..."
I18N_MESSAGES["ssh.socket.start_error"]="Ошибка запуска SSH сервиса"
I18N_MESSAGES["ssh.socket.active"]="SSH сервис активен в service mode"

# UFW messages

# Error messages
I18N_MESSAGES["ufw.error.enable_failed"]="Ошибка при активации [ufw --force enable]"

# Success messages
I18N_MESSAGES["ufw.success.backup_created"]="Создан бэкап: [%s]"
I18N_MESSAGES["ufw.error.backup_failed"]="Не удалось создать бэкап %s [%s]"
I18N_MESSAGES["ufw.success.before_rules_edited"]="Отредактирован: [%s]"
I18N_MESSAGES["ufw.success.reloaded"]="UFW перезагружен [ufw reload]"
I18N_MESSAGES["ufw.success.enabled"]="UFW включен"
I18N_MESSAGES["ufw.warning.continue_without_rules"]="Невозможно продолжить: нет правил BSSS в UFW"
I18N_MESSAGES["ufw.warning.add_ssh_first"]="Сначала добавьте SSH-порт через модуль SSH"
I18N_MESSAGES["ufw.rollback.test_access"]="Проверьте доступ к серверу после включения UFW в новом окне терминала"

# Menu messages
I18N_MESSAGES["ufw.menu.item_disable"]="Выключить UFW"
I18N_MESSAGES["ufw.menu.item_enable"]="Включить UFW"
I18N_MESSAGES["ufw.menu.item_ping_enable"]="Ping будет включен [ACCEPT] [По умолчанию]"
I18N_MESSAGES["ufw.menu.item_ping_disable"]="Ping будет отключен [DROP]"

# Status messages
I18N_MESSAGES["ufw.status.enabled"]="UFW включен"
I18N_MESSAGES["ufw.status.disabled"]="UFW отключен"
I18N_MESSAGES["ufw.status.ping_blocked"]="UFW ping запрещен [DROP] [Состояние: модифицировано]"
I18N_MESSAGES["ufw.status.ping_allowed"]="UFW ping разрешен [ACCEPT] [Состояние: по умолчанию]"

# Info messages
I18N_MESSAGES["ufw.info.no_rules_but_active"]="Нет правил BSSS, но UFW активен - можно отключить"

# Success messages
I18N_MESSAGES["ufw.success.backup_restored"]="Восстановлен файл before.rules: [%s]"

# Error messages
I18N_MESSAGES["ufw.error.restore_failed"]="Не удалось восстановить %s из бэкапа [%s]"
I18N_MESSAGES["ufw.error.edit_failed"]="Ошибка при редактировании: [%s]"
I18N_MESSAGES["ufw.error.reload_failed"]="Не удалось выполнить [ufw reload] [RC: %s]"

# System messages

# Update module
I18N_MESSAGES["system.update.apt_not_found"]="Менеджер пакетов apt-get не найден"
I18N_MESSAGES["system.update.error"]="Ошибка при обновлении системных пакетов"
I18N_MESSAGES["system.update.confirm"]="Обновить системные пакеты? [apt-get update && apt-get upgrade -y]"

# Reload check module
I18N_MESSAGES["system.reload.not_required"]="Перезагрузка не требуется"
I18N_MESSAGES["system.reload.reboot_required"]="Система нуждается в перезагрузке %s"
I18N_MESSAGES["system.reload.pkgs_header"]="Пакеты требующие перезагрузки:"

# Common helpers
I18N_MESSAGES["common.helpers.validate_order.error_missing_tag"]="Отсутствует обязательный тег MODULE_ORDER: %s"
I18N_MESSAGES["common.helpers.validate_order.error_duplicate"]="Дублирующийся MODULE_ORDER (%s): %s"

I18N_MESSAGES["common.helpers.ssh.no_active_ports"]="Нет активных SSH портов [ss -ltnp]"
I18N_MESSAGES["common.helpers.ssh.active_ports"]="Есть активные SSH порты [ss -ltnp]: %s"
I18N_MESSAGES["common.helpers.ufw.rules_found"]="Есть правила UFW [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules_not_found"]="Нет правил UFW [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules.sync"]="Правила UFW синхронизированы с настройками ${UTIL_NAME^^} для SSH порта"
I18N_MESSAGES["common.helpers.ufw.rules.delete_warning"]="Удаляя правила SSH, также будут удалены связанные правила UFW"
I18N_MESSAGES["common.helpers.ufw.rule.deleted"]="Удалено правило UFW: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.delete_error"]="Ошибка при удалении правила UFW: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.added"]="Создано правило UFW: [ufw allow %s/tcp comment '$BSSS_MARKER_COMMENT']"
I18N_MESSAGES["common.helpers.ufw.rule.add_error"]="Ошибка при добавлении правила UFW: [ufw allow %s/tcp comment ${UTIL_NAME^^}]"
I18N_MESSAGES["common.helpers.ufw.disabled"]="UFW: Полностью деактивирован [ufw --force disable]"
I18N_MESSAGES["common.helpers.ufw.already_disabled"]="UFW: деактивирован"
I18N_MESSAGES["common.helpers.rollback.stop_signal"]="Посылаем сигнал отключения rollback USR1 [PID: %s]"
I18N_MESSAGES["common.helpers.rollback.stop_received"]="Получен сигнал USR1 - остановка скрипта из-за отката"
I18N_MESSAGES["common.exit_received"]="Получен сигнал EXIT [RC: %s]"
I18N_MESSAGES["common.int_received"]="Получен сигнал INT [RC: %s]"
I18N_MESSAGES["common.helpers.rollback.fifo_created"]="Создан FIFO: %s"

# UFW check
I18N_MESSAGES["ufw.check.installed_restart"]="UFW установлен - перезапустите скрипт"

# OS check
I18N_MESSAGES["os.check.file_not_found"]="Файл не существует: %s"
I18N_MESSAGES["os.check.unsupported"]="Система %s не поддерживается (ожидалось: %s)"
I18N_MESSAGES["os.check.supported"]="Система %s поддерживается"

# User create module
I18N_MESSAGES["user.check.user_count"]="Количество пользователей (UID >= 1000): %s"
I18N_MESSAGES["user.check.only_root"]="В системе только пользователь root"
I18N_MESSAGES["user.check.user_exists"]="Пользователь: %s"
I18N_MESSAGES["user.create.create_error"]="Ошибка при создании пользователя"
I18N_MESSAGES["user.create.other_users_exist"]="Дополнительный пользователь уже создан"

# User create menu
I18N_MESSAGES["user.create.menu.header"]="Что будет происходить:"
I18N_MESSAGES["user.create.menu.create_user"]="Создание: [useradd -m -d /home/%s -s /bin/bash -G sudo %s]"
I18N_MESSAGES["user.create.menu.generate_pass"]="Генерация пароля: [openssl rand -base64 %s]"
I18N_MESSAGES["user.create.menu.create_sudoers"]="Создание правил в %s/%s"
I18N_MESSAGES["user.create.menu.password_once"]="Пароль будет выведен только раз на экран терминала (в логи не пишется)"
I18N_MESSAGES["user.create.menu.after_create"]="После создания пользователя необходимо скопировать ваш SSH ключ на сервер командой ssh-copy-id"
I18N_MESSAGES["user.create.menu.check_key"]="Проверить авторизацию по ключу и если все ок, то можно запрещать доступ по паролю и доступ от имени root"
I18N_MESSAGES["user.create.menu.reminder"]="Напоминание, как удалить пользователя:"
I18N_MESSAGES["user.create.menu.reminder_deluser"]="deluser --remove-home --remove-all-files USERNAME # Удалить пользователя"
I18N_MESSAGES["user.create.menu.reminder_find"]="find / -uid USERID 2>/dev/null # Найти все созданные файлы по id"
I18N_MESSAGES["user.create.menu.reminder_sudoers"]="grep -r -E 'USERNAME.*ALL' /etc/sudoers.d/ # Поиск правил пользователя"
I18N_MESSAGES["user.create.menu.reminder_pgrep"]="pgrep -u USERNAME # посмотреть PID процессов"
I18N_MESSAGES["user.create.menu.reminder_killall"]="killall -9 -u USERNAME # завершить все процессы"
I18N_MESSAGES["user.create.menu.item_create"]="Создать пользователя"
I18N_MESSAGES["user.create.menu.user_created"]="Пользователь %s создан, пароль назначен"
I18N_MESSAGES["user.create.menu.password_no_log"]="Не логируется >>>[%s]<<<"
I18N_MESSAGES["user.create.menu.after_copy_key"]="После копирования SSH ключа и успешного подключения можно будет запретить авторизацию по паролю"

# Permissions messages
I18N_MESSAGES["permissions.menu.item_create"]="Создать правила ${UTIL_NAME^^} для доступа"
I18N_MESSAGES["permissions.menu.item_remove"]="Удалить правила ${UTIL_NAME^^} для доступа"
I18N_MESSAGES["permissions.info.create_rules"]="Будет создан файл с правилами в каталоге %s"
I18N_MESSAGES["permissions.guard.test_access"]="Проверьте доступ к серверу в новом окне терминала"

# Permissions check
I18N_MESSAGES["permissions.check.info.check_params"]="Проверка: PubkeyAuthentication|PasswordAuthentication|PermitRootLogin"

# Permissions warnings
I18N_MESSAGES["permissions.warn.auth_by_ssh_key_user"]="Обнаружено подлючение под root-пользователем. Авторизуйтесь по SSH ключу sudo-пользователем (не root). Автоматическая настройка создает в том числе правила ограничивающие авторизацию под root. Сейчас владелец сессии %s."
I18N_MESSAGES["permissions.attention.password_connection"]="Обнаружено подключение по паролю. В автоматическом режиме создаются правила запрещающие авторизацию по паролю. Подключитесь под sudo-пользователем (не root) по SSH ключу."
I18N_MESSAGES["permissions.warn.session_timeout_limitations"]="Сессия длиннее 72 часов [невозможно определить тип подключения - ограничения журнала]"
I18N_MESSAGES["permissions.warn.reconnect_new_window"]="Подключитесь заново в новом окне терминала [%s]"
I18N_MESSAGES["permissions.warn.cannot_determine_connection"]="Не удалось определить тип подключения"

# Permissions confirm
I18N_MESSAGES["permissions.confirm.reset_rules"]="Выполнить сброс правил %s для доступа?"

# Permissions info
I18N_MESSAGES["permissions.info.only_reset_available"]="В таком режиме возможен только сброс настроек"

# Common unified messages (reusable across modules)
I18N_MESSAGES["common.info.rules_found"]="Есть правила %s для доступа:"
I18N_MESSAGES["common.info.no_rules"]="Нет правил %s для доступа"
I18N_MESSAGES["common.info.external_rules_found"]="Найдены сторонние правила для доступа"
I18N_MESSAGES["common.info.no_external_rules"]="Нет сторонних правил для доступа"
I18N_MESSAGES["common.file.created"]="Файл создан: %s"
I18N_MESSAGES["common.error.create_file"]="Ошибка при создании файла: %s"
I18N_MESSAGES["common.info.users_in_system"]="Пользователи в системе:"
I18N_MESSAGES["common.error.check_users"]="Ошибка проверки состава пользователей"
