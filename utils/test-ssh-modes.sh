#!/usr/bin/env bash
# Утилита для тестирования переключения SSH между socket и service режимами

set -Eeuo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")"))" )" && pwd)"
readonly CURRENT_MODULE_NAME="test-ssh-modes"

source "${PROJECT_DIR}/modules/03-ssh-socket-helpers.sh"
source "${PROJECT_DIR}/lib/logging.sh"
source "${PROJECT_DIR}/modules/common-helpers.sh"

# @type:        Filter
# @description: Сбрасывает счетчики ошибок сервисов systemd
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка
ssh::reset_failed_services() {
    systemctl reset-failed
}

# @type:        Orchestrator
# @description: Отображает текущий режим SSH
show_current_mode() {
    log::draw_border
    if ssh::is_socket_mode; then
        log_info "Текущий режим: SOCKET-ACTIVATION (ssh.socket активен)"
    elif ssh::is_service_mode; then
        log_info "Текущий режим: CLASSIC SERVICE (ssh.service активен)"
    else
        log_error "SSH не активен или в неизвестном состоянии"
    fi
    
    log_info "Active SSH:"
    if command -v ss >/dev/null 2>&1; then
        ss -ltnp 2>/dev/null | awk '($4 ~ /:22\s/ || $4 ~ /:22$/) {print}'
    fi
    log::draw_border
}

# @type:        Orchestrator
# @description: Переключает на socket режим
switch_to_socket() {
    log::draw_border
    log_info "Переключение на SOCKET режим..."
    ssh::switch_to_socket_mode
    log_success "Переключение завершено"
    show_current_mode
}

# @type:        Orchestrator
# @description: Переключает на service режим
switch_to_service() {
    log::draw_border
    log_info "Переключение на SERVICE режим..."
    ssh::switch_to_service_mode
    log_success "Переключение завершено"
    show_current_mode
}

# @type:        Orchestrator
# @description: Сбрасывает счетчики ошибок
reset_failed() {
    log::draw_border
    log_info "Сброс счетчиков ошибок сервисов..."
    ssh::reset_failed_services
    log_success "Сброс выполнен"
}

# @type:        Orchestrator
# @description: Валидация конфигурации sshd
validate_sshd() {
    log::draw_border
    log_info "Проверка конфигурации sshd..."
    if sys::validate_sshd_config; then
        log_success "Конфигурация валидна"
    else
        log_error "Конфигурация содержит ошибки"
        return 1
    fi
    log::draw_border
}

show_help() {
    cat << 'EOF'
Использование: bash utils/test-ssh-modes.sh [COMMAND]

Команды:
    status      Показать текущий режим SSH
    socket      Переключить на socket режим (для тестирования)
    service     Переключить на service режим (классический)
    reset       Сбросить счетчики ошибок сервисов
    validate    Проверить конфигурацию sshd
    help        Показать эту справку

Примеры:
    bash utils/test-ssh-modes.sh status
    bash utils/test-ssh-modes.sh socket
    bash utils/test-ssh-modes.sh service
EOF
}

main() {
    local command="${1:-help}"
    
    case "$command" in
        status)
            show_current_mode
            ;;
        socket)
            switch_to_socket
            ;;
        service)
            switch_to_service
            ;;
        reset)
            reset_failed
            ;;
        validate)
            validate_sshd
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Неизвестная команда: $command"
            show_help
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
