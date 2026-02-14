# System messages (Russian)

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
I18N_MESSAGES["common.helpers.file.delete.error"]="Ошибка удаления %s: %s"
I18N_MESSAGES["common.helpers.file.delete.success"]="Удалено: %s"
I18N_MESSAGES["common.helpers.ssh.no_active_ports"]="Нет активных SSH портов [ss -ltnp]"
I18N_MESSAGES["common.helpers.ssh.active_ports"]="Есть активные SSH порты [ss -ltnp]: %s"
I18N_MESSAGES["common.helpers.ufw.rules_found"]="Есть правила UFW [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules_not_found"]="Нет правил UFW [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules.sync"]="Правила UFW синхронизированы с настройками ${UTIL_NAME^^} для SSH порта"
I18N_MESSAGES["common.helpers.ufw.rules.delete_warning"]="Удаляя правила SSH, также будут удалены связанные правила UFW"
I18N_MESSAGES["common.helpers.ufw.rule.deleted"]="Удалено правило UFW: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.delete_error"]="Ошибка при удалении правила UFW: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.added"]="Создано правило UFW: [ufw allow %s/tcp comment '$BSSS_MARKER_COMMENT]'"
I18N_MESSAGES["common.helpers.ufw.rule.add_error"]="Ошибка при добавлении правила UFW: [ufw allow %s/tcp comment ${UTIL_NAME^^}]"
I18N_MESSAGES["common.helpers.ufw.disabled"]="UFW: Полностью деактивирован [ufw --force disable]"
I18N_MESSAGES["common.helpers.ufw.already_disabled"]="UFW: деактивирован"
I18N_MESSAGES["common.helpers.rollback.stop_signal"]="Посылаем сигнал отключения rollback USR1 [PID: %s]"
I18N_MESSAGES["common.helpers.rollback.stop_received"]="Получен сигнал USR1 - остановка скрипта из-за отката"
I18N_MESSAGES["common.helpers.rollback.exit_received"]="Получен сигнал EXIT [RC: %s]"
I18N_MESSAGES["common.helpers.rollback.int_received"]="Получен сигнал INT [RC: %s]"
I18N_MESSAGES["common.helpers.rollback.fifo_created"]="Создан FIFO: %s"

# Init helpers

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
I18N_MESSAGES["user.create.confirm"]="Создать пользователя %s?"
I18N_MESSAGES["user.create.creating_user"]="Создание пользователя: %s"
I18N_MESSAGES["user.create.user_created"]="Пользователь создан"
I18N_MESSAGES["user.create.create_error"]="Ошибка при создании пользователя"
I18N_MESSAGES["user.create.password_set"]="Пароль установлен"
I18N_MESSAGES["user.create.user_created_with_password"]="Пользователь '%s' создан. Пароль: %s"
I18N_MESSAGES["user.create.other_users_exist"]="Дополнительный пользователь уже создан"
I18N_MESSAGES["user.create.openssl_not_found"]="openssl не найден, невозможно сгенерировать пароль"

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

# Permissions check module
I18N_MESSAGES["permissions.check.header"]="=== Проверка прав доступа SSH ==="
I18N_MESSAGES["permissions.check.current_connection"]="Текущее подключение: [%s]"
I18N_MESSAGES["permissions.check.current_user"]="Текущий пользователь: [%s]"
I18N_MESSAGES["permissions.check.root_uid"]="Root UID: [%s]"
I18N_MESSAGES["permissions.check.status_header"]="=== Статус отключения логина по паролю и root ==="
I18N_MESSAGES["permissions.check.require_ssh_key"]="Требуется подключение по SSH ключу"
I18N_MESSAGES["permissions.check.require_nonroot"]="Требуется подключение пользователем отличным от root"
I18N_MESSAGES["permissions.check.can_disable"]="Можно отключать PermitRootLogin и PasswordAuthentication"

# Permissions modify module
I18N_MESSAGES["permissions.modify.no_config_files"]="Файлы с настройками не найдены, используется префикс: %s"
I18N_MESSAGES["permissions.modify.found_prefix"]="Найден последний префикс: %s"
I18N_MESSAGES["permissions.modify.creating_config"]="Создание файла конфигурации: %s"
I18N_MESSAGES["permissions.modify.file_created"]="Файл создан"
