# UFW messages (Russian)

# Modify messages
I18N_MESSAGES["ufw.modify.confirm"]="Изменить состояние UFW?"

# Error messages
I18N_MESSAGES["ufw.error.enable_failed"]="Ошибка при активации [ufw --force enable]"

# Success messages
I18N_MESSAGES["ufw.success.backup_created"]="Создан бэкап: [%s]"
I18N_MESSAGES["ufw.error.backup_failed"]="Не удалось создать бэкап %s [%s]"
I18N_MESSAGES["ufw.success.before_rules_edited"]="Отредактирован: [%s]"
I18N_MESSAGES["ufw.success.reloaded"]="UFW перезагружен [ufw reload]"
I18N_MESSAGES["ufw.warning.continue_without_rules"]="Невозможно продолжить: нет правил BSSS в UFW"
I18N_MESSAGES["ufw.warning.add_ssh_first"]="Сначала добавьте SSH-порт через модуль SSH"
I18N_MESSAGES["ufw.rollback.warning_title"]="НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
I18N_MESSAGES["ufw.rollback.test_access"]="Проверьте доступ к серверу после включения UFW"
I18N_MESSAGES["ufw.install.confirm_connection"]="Подтвердите возможность подключения - введите connected или 0 для отмены"

# Menu messages
I18N_MESSAGES["ufw.menu.ask_select"]="Выберите действие"
I18N_MESSAGES["ufw.menu.item_disable"]="Выключить UFW"
I18N_MESSAGES["ufw.menu.item_enable"]="Включить UFW"
I18N_MESSAGES["ufw.menu.item_ping_enable"]="Ping будет включен [ACCEPT] [По умолчанию]"
I18N_MESSAGES["ufw.menu.item_ping_disable"]="Ping будет отключен [DROP]"
I18N_MESSAGES["ufw.menu.item_exit"]="Выход"

# Status messages
I18N_MESSAGES["ufw.status.enabled"]="UFW включен"
I18N_MESSAGES["ufw.status.disabled"]="UFW отключен"
I18N_MESSAGES["ufw.status.ping_blocked"]="UFW ping запрещен [DROP] [Состояние: модифицировано]"
I18N_MESSAGES["ufw.status.ping_allowed"]="UFW ping разрешен [ACCEPT] [Состояние: по умолчанию]"

# Info messages
I18N_MESSAGES["ufw.info.no_rules_but_active"]="Нет правил BSSS, но UFW активен - можно отключить"

# Success messages
I18N_MESSAGES["ufw.success.enabled"]="UFW: Активирован [ufw --force enable]"
I18N_MESSAGES["ufw.success.icmp_changed"]="ICMP правила изменены на DROP"
I18N_MESSAGES["ufw.success.backup_restored"]="Восстановлен файл before.rules: [%s]"

# Error messages
I18N_MESSAGES["ufw.error.invalid_menu_id"]="Неверный ID действия: [%s]"
I18N_MESSAGES["ufw.error.backup_failed"]="Не удалось создать бэкап %s [%s]"
I18N_MESSAGES["ufw.error.restore_failed"]="Не удалось восстановить %s из бэкапа [%s]"
I18N_MESSAGES["ufw.error.edit_failed"]="Ошибка при редактировании: [%s]"
I18N_MESSAGES["ufw.error.reload_failed"]="Не удалось выполнить [ufw reload] [Code: %s]"
