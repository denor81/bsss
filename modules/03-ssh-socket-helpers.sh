# @type:        Filter
# @description: Проверяет, настроен ли SSH в service mode
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - SSH уже настроен в service mode
#               1 - требуется настройка
ssh::socket::is_already_configured() {
    # Если сервис активен И сокет замаскирован — значит, мы уже всё настроили
    if systemctl is-active --quiet ssh.service && [[ "$(systemctl is-enabled ssh.socket 2>/dev/null)" == "masked" ]]; then
        return 0
    fi
    return 1
}

# @type:        Orchestrator
# @description: Принудительно переключает SSH в service mode
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - SSH успешно переведен в service mode
#               1 - ошибка при запуске SSH
ssh::socket::force_service_mode() {
    log_info "Принудительная синхронизация SSH к Service Mode..."

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


