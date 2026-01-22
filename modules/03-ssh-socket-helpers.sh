#!/usr/bin/env bash
# Хелперы для работы с SSH socket/service режимами
# MODULE_TYPE: helper

set -Eeuo pipefail

# @type:        Filter
# @description: Проверяет, активен ли ssh.socket (socket-активация)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - ssh.socket активен
#               1 - ssh.socket не активен
ssh::is_socket_mode() {
    systemctl is-active --quiet ssh.socket
}

# @type:        Filter
# @description: Проверяет, активен ли ssh.service
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - ssh.service активен
#               1 - ssh.service не активен
ssh::is_service_mode() {
    systemctl is-active --quiet ssh.service
}

# @type:        Orchestrator
# @description: Переключает SSH с socket на service режим
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно переключен
#               1 - ошибка переключения
ssh::switch_to_service_mode() {
    if ssh::is_socket_mode; then
        log_info "Отключение ssh.socket..."
        if systemctl disable --now ssh.socket; then
            log_info "Включение ssh.service..."
            if systemctl enable --now ssh.service; then
                log_info "Перезагрузка systemd..."
                systemctl daemon-reload
                return 0
            else
                log_error "Ошибка включения ssh.service"
                return 1
            fi
        else
            log_error "Ошибка отключения ssh.socket"
            return 1
        fi
    else
        log_info "SSH уже работает в режиме service"
        return 0
    fi
}


