#!/usr/bin/env bash
# Проверяет режим запуска SSH (socket vs service)
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/03-ssh-socket-helpers.sh"

# @type:        Orchestrator
# @description: Проверяет режим запуска SSH и переключает на service если нужно
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - режим корректен или успешно переключен
#               1 - отказ от переключения (strict mode, выполнение невозможно)
check() {
    if ssh::is_socket_mode; then
        log_error "SSH работает в режиме socket-активации"
        log_warn "Этот режим может вызывать проблемы с поднятием портов после изменения конфигурации"
        
        if io::confirm_action "Переключиться на классический режим ssh.service?"; then
            if ssh::switch_to_service_mode; then
                log_success "SSH успешно переключен на режим service"
                return 0
            else
                log_error "Ошибка при переключении режима SSH"
                return 1
            fi
        else
            log_error "Отказ от переключения режима. Выполнение невозможно."
            return 1
        fi
    else
        log_info "SSH работает в классическом режиме (service)"
        return 0
    fi
}

main() {
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
