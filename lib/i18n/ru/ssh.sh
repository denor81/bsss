# SSH port messages (Russian)

# Menu UI
I18N_MESSAGES["ssh.ui.get_action_choice.available_actions"]="Доступные действия:"
I18N_MESSAGES["ssh.ui.get_action_choice.option_reset"]="Сброс (удаление правила ${UTIL_NAME^^})"
I18N_MESSAGES["ssh.ui.get_action_choice.option_reinstall"]="Переустановка (замена на новый порт)"
I18N_MESSAGES["ssh.ui.get_action_choice.option_exit"]="Выход"
I18N_MESSAGES["ssh.ui.get_action_choice.ask_select"]="Выберите действие"
I18N_MESSAGES["ssh.ui.get_action_choice.hint"]="Выберите число от 0 до 2"

# Input prompts
I18N_MESSAGES["ssh.ui.get_new_port.ask_port"]="Введите новый SSH порт"
I18N_MESSAGES["ssh.ui.get_new_port.hint"]="Порт должен быть от 1 до 65535"
I18N_MESSAGES["ssh.ui.get_new_port.default"]="22"
I18N_MESSAGES["ssh.ui.get_action_choice.ask_select"]="Выберите"
I18N_MESSAGES["ssh.install.confirm_connection"]="Подтвердите подключение - введите connected"

# Info messages
I18N_MESSAGES["ssh.info_rules_found"]="Есть правила ${UTIL_NAME^^} для SSH:"
I18N_MESSAGES["ssh.info_no_rules"]="Нет правил ${UTIL_NAME^^} для SSH [%s]"

# Success messages
I18N_MESSAGES["ssh.success_port_up"]="SSH порт %s успешно поднят после %s попыток в течение %s сек"
I18N_MESSAGES["ssh.success_rule_created"]="Создано правило ${UTIL_NAME^^} для SSH: [%s:%s]"
I18N_MESSAGES["ssh.success_changes_committed"]="Изменения зафиксированы, Rollback отключен"

# Error messages
I18N_MESSAGES["ssh.error_port_busy"]="SSH порт %s уже занят другим сервисом."
I18N_MESSAGES["ssh.error_rule_creation_failed"]="Не удалось создать правило SSH: %s"
I18N_MESSAGES["ssh.error_config_sshd"]="Ошибка конфигурации ssh [sshd -t]"

# Warning messages
I18N_MESSAGES["ssh.warning_external_rules_found"]="Есть сторонние правила SSH:"
I18N_MESSAGES["ssh.warning_no_external_rules"]="Нет сторонних правил SSH [%s]"

# Wait messages
I18N_MESSAGES["ssh.socket.wait_for_ssh_up.info"]="Ожидание поднятия SSH порта %s (таймаут: %s сек)..."

# Menu items
I18N_MESSAGES["ssh.menu.item_reset"]="1. Сброс (удаление правила %s)"
I18N_MESSAGES["ssh.menu.item_reinstall"]="2. Переустановка (замена на новый порт)"
I18N_MESSAGES["ssh.menu.item_exit"]="0. Выход"

# Input messages
I18N_MESSAGES["ssh.ui.get_new_port.prompt"]="Введите новый SSH порт"
I18N_MESSAGES["ssh.ui.get_new_port.hint_range"]="1-65535, Enter для %s"

# Service messages
I18N_MESSAGES["ssh.service.daemon_reloaded"]="Конфигурация перезагружена [systemctl daemon-reload]"
I18N_MESSAGES["ssh.service.restarted"]="SSH сервис перезагружен [systemctl restart ssh.service]"

# Guard instructions
I18N_MESSAGES["ssh.guard.dont_close"]="НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
I18N_MESSAGES["ssh.guard.test_new"]="ОТКРОЙТЕ НОВОЕ ОКНО и проверьте связь через порт %s"

# Error messages
I18N_MESSAGES["ssh.error_port_not_up"]="ПОРТ %s НЕ ПОДНЯЛСЯ [%s попыток в течение %s сек]"
I18N_MESSAGES["ssh.error_invalid_choice"]="Не корректный выбор"
