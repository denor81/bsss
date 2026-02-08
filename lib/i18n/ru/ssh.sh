# SSH port messages (Russian)

# Modify messages
I18N_MESSAGES["ssh.modify.confirm"]="Изменить конфигурацию SSH порта?"

# Menu UI
I18N_MESSAGES["ssh.ui.get_action_choice.ask_select"]="Выберите действие"

# Input prompts
I18N_MESSAGES["ssh.install.confirm_connection"]="Подтвердите подключение - введите connected или 0 для отмены"

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
I18N_MESSAGES["ssh.socket.unit_not_found"]="Юнит ssh.service не найден в системе"
I18N_MESSAGES["ssh.socket.script_purpose"]="Этот скрипт переключает SSH в режим service"

# Warning messages
I18N_MESSAGES["ssh.warning_external_rules_found"]="Есть сторонние правила SSH:"
I18N_MESSAGES["ssh.warning_no_external_rules"]="Нет сторонних правил SSH [%s]"

# Wait messages
I18N_MESSAGES["ssh.socket.wait_for_ssh_up.info"]="Ожидание поднятия SSH порта %s (таймаут: %s сек)..."

# Menu items
I18N_MESSAGES["ssh.menu.item_reset"]="%s. Сброс (удаление правила %s)"
I18N_MESSAGES["ssh.menu.item_reinstall"]="%s. Переустановка (замена на новый порт)"

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

# Socket check messages
I18N_MESSAGES["ssh.socket.configured"]="SSH уже настроен корректно в service mode"
I18N_MESSAGES["ssh.socket.mode_warning"]="SSH работает в socket-based activation mode, что может конфликтовать с изменением порта через sshd_config"
I18N_MESSAGES["ssh.socket.mode_required"]="Требуется переключение SSH в традиционный service mode"
I18N_MESSAGES["ssh.socket.switch_confirm"]="Переключить SSH в традиционный service mode?"
I18N_MESSAGES["ssh.socket.socket_masked"]="ssh.socket замаскирован (masked) - SSH работает в традиционном service mode"
I18N_MESSAGES["ssh.socket.socket_enabled"]="ssh.socket активен - SSH работает в socket-based activation mode"
I18N_MESSAGES["ssh.socket.socket_disabled"]="ssh.socket отключен"
I18N_MESSAGES["ssh.socket.socket_status"]="Статус ssh.socket: %s"
I18N_MESSAGES["ssh.socket.not_found_traditional_mode"]="ssh.socket не найден - SSH работает в традиционном service mode (Ubuntu 20.04 или сконфигурирован вручную)"
