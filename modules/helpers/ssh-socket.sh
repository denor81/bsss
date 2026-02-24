# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Проверяет, настроен ли SSH в service mode
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - SSH уже настроен в service mode
#               1 - требуется настройка
ssh::socket::is_already_configured() {
    local unit_socket="ssh.socket"

    # 1. Если сервис не активен — конфигурация точно не завершена
    if ! sys::ssh::is_service_active; then
        return 1
    fi

    # 2. Если ssh.socket не существует (Ubuntu 20.04 или был удален) —
    # считаем, что SSH уже работает в традиционном service mode
    if ! sys::ssh::unit_exists "$unit_socket"; then
        return 0
    fi

    # 3. Если сокет есть, проверяем его статус через is-enabled.
    # Нам нужно именно значение "masked".
    local socket_enabled_status
    socket_enabled_status=$(systemctl is-enabled "$unit_socket" 2>/dev/null)

    [[ "$socket_enabled_status" == "masked" ]]
}

# @type:        Validator
# @description: Проверяет, существует ли systemd юнит
# @params:      unit_name Название юнита (string)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - существует
#               1 - не существует
sys::ssh::unit_exists() {
    local unit_name="$1"
    systemctl list-unit-files "$unit_name" --quiet >/dev/null 2>&1
}

# @type:        Validator
# @description: Проверяет, активен ли ssh.service
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - активен
#               1 - не активен
sys::ssh::is_service_active() {
    systemctl is-active --quiet "ssh.service"
}

# @type:        Orchestrator
# @description: Переключает SSH в service mode
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - SSH успешно переведен в service mode
#               1 - ошибка при запуске SSH
ssh::socket::force_service_mode() {
    log_info "$(_ "ssh.socket.force_mode")"

    log_info "$(_ "common.log_command" "systemctl stop ssh.socket")"
    systemctl stop ssh.socket >/dev/null 2>&1

    log_info "$(_ "common.log_command" "systemctl disable ssh.socket")"
    systemctl disable ssh.socket >/dev/null 2>&1

    log_info "$(_ "common.log_command" "systemctl mask ssh.socket")"
    systemctl mask ssh.socket >/dev/null 2>&1

    log_info "$(_ "common.log_command" "systemctl unmask ssh.service")"
    systemctl unmask ssh.service >/dev/null 2>&1

    log_info "$(_ "common.log_command" "systemctl enable ssh.service")"
    systemctl enable ssh.service >/dev/null 2>&1

    if ! systemctl is-active --quiet ssh.service; then
        log_info "$(_ "ssh.socket.service_not_active")"
        log_info "$(_ "common.log_command" "systemctl start ssh.service")"
        if ! systemctl start ssh.service; then
            log_error "$(_ "ssh.socket.start_error")"
            return 1
        fi
    else
        log_info "$(_ "common.log_command" "systemctl restart ssh.service")"
        systemctl restart ssh.service >/dev/null 2>&1
    fi

    if systemctl is-active --quiet ssh.service; then
        log_success "$(_ "ssh.socket.active")"
        return 0
    fi

    return 1
}


