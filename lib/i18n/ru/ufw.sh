# UFW messages (Russian)
declare -gA I18N_MESSAGES

# Menu UI
I18N_MESSAGES["ufw.menu.display.available_actions"]="Доступные действия:"
I18N_MESSAGES["ufw.menu.display.no_rules"]="Нет правил BSSS, но UFW активен - можно отключить"
I18N_MESSAGES["ufw.menu.display.exit"]="Выход"

# Info messages
I18N_MESSAGES["ufw.info.enabled"]="UFW включен"
I18N_MESSAGES["ufw.info.disabled"]="UFW отключен"
I18N_MESSAGES["ufw.info.ping_blocked"]="UFW ping запрещен [DROP] [Состояние: модифицировано]"
I18N_MESSAGES["ufw.info.ping_allowed"]="UFW ping разрешен [ACCEPT] [Состояние: по умолчанию]"

# Error messages
I18N_MESSAGES["ufw.error.enable_failed"]="Ошибка при активации [ufw --force enable]"
I18N_MESSAGES["ufw.error.disable_failed"]="Ошибка при отключении [ufw --force disable]"

# Success messages
I18N_MESSAGES["ufw.success.backup_created"]="Создан бэкап: [%s]"
I18N_MESSAGES["ufw.success.backup_failed"]="Не удалось создать бэкап %s [%s]"
I18N_MESSAGES["ufw.success.before_rules_edited"]="Отредактирован: [%s]"
I18N_MESSAGES["ufw.success.before_rules_restore_failed"]="Ошибка при редактировании: [%s]"
I18N_MESSAGES["ufw.success.rules_deleted"]="Правила BSSS удалены"
I18N_MESSAGES["ufw.success.reloaded"]="UFW перезагружен [ufw reload]"

# Warning messages
I18N_MESSAGES["ufw.warning.backup_not_found"]="Бэкап не найден"
I18N_MESSAGES["ufw.warning.continue_without_rules"]="Невозможно продолжить: нет правил BSSS в UFW"
I18N_MESSAGES["ufw.rollback.warning_title"]="НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
I18N_MESSAGES["ufw.rollback.ask_confirm"]="Подтвердите возможность подключения - введите connected"
