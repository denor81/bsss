# SSH port messages (Russian)
declare -gA SSH_MESSAGES

# Menu UI
SSH_MESSAGES["ssh.ui.get_action_choice.available_actions"]="Доступные действия:"
SSH_MESSAGES["ssh.ui.get_action_choice.option_reset"]="Сброс (удаление правила ${UTIL_NAME^^})"
SSH_MESSAGES["ssh.ui.get_action_choice.option_reinstall"]="Переустановка (замена на новый порт)"
SSH_MESSAGES["ssh.ui.get_action_choice.option_exit"]="Выход"
SSH_MESSAGES["ssh.ui.get_action_choice.ask_select"]="Выберите действие"
SSH_MESSAGES["ssh.ui.get_action_choice.hint"]="Выберите число от 0 до 2"

# Input prompts
SSH_MESSAGES["ssh.ui.get_new_port.ask_port"]="Введите новый SSH порт"
SSH_MESSAGES["ssh.ui.get_new_port.hint"]="Порт должен быть от 1 до 65535"
SSH_MESSAGES["ssh.ui.get_new_port.default"]="22"

# Info messages
SSH_MESSAGES["ssh.info_rules_found"]="Есть правила ${UTIL_NAME^^} для SSH:"
SSH_MESSAGES["ssh.info_no_rules"]="Нет правил ${UTIL_NAME^^} для SSH [%s]"

# Success messages
SSH_MESSAGES["ssh.success_port_up"]="SSH порт %s успешно поднят после %s попыток в течение %s сек"
SSH_MESSAGES["ssh.success_rule_created"]="Создано правило ${UTIL_NAME^^} для SSH: [%s:%s]"
SSH_MESSAGES["ssh.success_changes_committed"]="Изменения зафиксированы, Rollback отключен"

# Error messages
SSH_MESSAGES["ssh.error_port_busy"]="SSH порт %s уже занят другим сервисом."
SSH_MESSAGES["ssh.error_rule_creation_failed"]="Не удалось создать правило SSH: %s"
SSH_MESSAGES["ssh.error_config_sshd"]="Ошибка конфигурации ssh [sshd -t]"

# Warning messages
SSH_MESSAGES["ssh.warning_external_rules_found"]="Есть сторонние правила SSH:"
SSH_MESSAGES["ssh.warning_no_external_rules"]="Нет сторонних правил SSH [%s]"
