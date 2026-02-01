# @type:        Filter
# @description: Проверяет, настроен ли SSH в service mode
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - SSH уже настроен в service mode
#               1 - требуется настройка
ssh::socket::is_already_configured() {
    local unit_socket="ssh.socket"

    # 1. Если сервис не активен — конфигурация точно не завершена
    sys::ssh::is_service_active

    # 2. Проверяем состояние сокета
    # Если его нет в системе — это нас устраивает выбрасываемся код 1
    sys::ssh::unit_exists "$unit_socket"

    # 3. Если сокет есть, проверяем его статус через is-enabled.
    # Нам нужно именно значение "masked".
    local socket_enabled_status
    socket_enabled_status=$(systemctl is-enabled "$unit_socket" 2>/dev/null)

    [[ "$socket_enabled_status" == "masked" ]]
}

# @type:        Source
# @description: Проверяет, существует ли юнит ssh.service
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - существует
#               1 - не существует
sys::ssh::unit_exists() {
    local unit_name="$1"
    systemctl list-unit-files "$unit_name" --quiet | grep -Fq "$unit_name"
}

# @type:        Filter
# @description: Проверяет, активен ли ssh.service
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - активен
#               1 - не активен
sys::ssh::is_service_active() {
    systemctl is-active --quiet "ssh.service"
}

# @type:        Orchestrator
# @description: Принудительно переключает SSH в service mode
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - SSH успешно переведен в service mode
#               1 - ошибка при запуске SSH
ssh::socket::force_service_mode() {
    log_info "Принудительное переключение SSH в Service Mode..."

    systemctl stop ssh.socket >/dev/null 2>&1
    systemctl disable ssh.socket >/dev/null 2>&1
    systemctl mask ssh.socket >/dev/null 2>&1

    systemctl unmask ssh.service >/dev/null 2>&1
    systemctl enable ssh.service >/dev/null 2>&1

    if ! systemctl is-active --quiet ssh.service; then
        log_info "Сервис не запущен. Пытаюсь стартовать..."
        if ! systemctl start ssh.service; then
            log_error "Не удалось запустить ssh.service. Проверьте 'journalctl -xeu ssh.service'"
            return 1
        fi
    else
        systemctl restart ssh.service >/dev/null 2>&1
    fi

    if systemctl is-active --quiet ssh.service; then
        log_success "SSH активен (Service Mode)"
        return 0
    fi

    return 1
}


