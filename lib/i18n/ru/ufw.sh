# UFW messages (Russian)
declare -gA UFW_MESSAGES

# Menu UI
UFW_MESSAGES["ufw.menu.display.available_actions"]="Доступные действия:"
UFW_MESSAGES["ufw.menu.display.no_rules"]="Нет правил BSSS, но UFW активен - можно отключить"
UFW_MESSAGES["ufw.menu.display.exit"]="Выход"

# Info messages
UFW_MESSAGES["ufw.info.enabled"]="UFW включен"
UFW_MESSAGES["ufw.info.disabled"]="UFW отключен"
UFW_MESSAGES["ufw.info.ping_blocked"]="UFW ping запрещен [DROP] [Состояние: модифицировано]"
UFW_MESSAGES["ufw.info.ping_allowed"]="UFW ping разрешен [ACCEPT] [Состояние: по умолчанию]"

# Error messages
UFW_MESSAGES["ufw.error.enable_failed"]="Ошибка при активации [ufw --force enable]"
UFW_MESSAGES["ufw.error.disable_failed"]="Ошибка при отключении [ufw --force disable]"

# Success messages
UFW_MESSAGES["ufw.success.backup_created"]="Создан бэкап: [%s]"
UFW_MESSAGES["ufw.success.backup_failed"]="Не удалось создать бэкап %s [%s]"
UFW_MESSAGES["ufw.success.before_rules_edited"]="Отредактирован: [%s]"
UFW_MESSAGES["ufw.success.before_rules_restore_failed"]="Ошибка при редактировании: [%s]"
UFW_MESSAGES["ufw.success.rules_deleted"]="Правила BSSS удалены"
UFW_MESSAGES["ufw.success.reloaded"]="UFW перезагружен [ufw reload]"

# Warning messages
UFW_MESSAGES["ufw.warning.backup_not_found"]="Бэкап не найден"
UFW_MESSAGES["ufw.warning.continue_without_rules"]="Невозможно продолжить: нет правил BSSS в UFW"
UFW_MESSAGES["ufw.rollback.warning_title"]="НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
UFW_MESSAGES["ufw.rollback.ask_confirm"]="Подтвердите возможность подключения - введите connected"
