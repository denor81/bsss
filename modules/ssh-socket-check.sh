#!/usr/bin/env bash
# Проверяет режим запуска SSH (socket vs service)
# MODULE_ORDER: 30
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-socket.sh"

# @type:        Validator
# @description: Проверяет существование ssh.service юнита
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - юнит существует
#               1 - юнит не установлен
check_unit() {
    if ! sys::ssh::unit_exists "ssh.service"; then
        log_error "$(_ "ssh.socket.unit_not_found")"
        log_info_simple_tab "$(_ "ssh.socket.script_purpose")"
        return 1
    fi

    # Проверяем наличие ssh.socket - если его нет, это нормально для Ubuntu 20.04
    # или если система уже была переведена в service mode
    if sys::ssh::unit_exists "ssh.socket"; then
        local socket_status
        # || true: is-enabled возвращает код 1 если юнит не включен - это нормально
        socket_status=$(systemctl is-enabled ssh.socket 2>/dev/null || true)

        case "$socket_status" in
            masked) : ;;
            enabled|static) log_info "$(_ "ssh.socket.socket_enabled")" ;;
            disabled) log_info "$(_ "ssh.socket.socket_disabled")" ;;
            *) log_info "$(_ "ssh.socket.socket_status" "$socket_status")" ;;
        esac
    else
        log_info "$(_ "ssh.socket.not_found_traditional_mode")"
    fi

    return 0
}

# @type:        Orchestrator
# @description: Настраивает SSH в service режим, если это необходимо
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - режим корректен или успешно переключен
#               1 - ошибка в ssh::socket::force_service_mode
#               2 - отказ пользователя от переключения в service mode
check() {
    if ssh::socket::is_already_configured; then
        log_info "$(_ "ssh.socket.configured")"
        return
    else
        log_error "$(_ "ssh.socket.mode_warning")"
        log_info "$(_ "ssh.socket.mode_required")"
        io::confirm_action "$(_ "ssh.socket.switch_confirm")"
        ssh::socket::force_service_mode
    fi
}

# @type:        Orchestrator
# @description: Точка входа модуля проверки SSH socket
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - проверка прошла успешно
#               2 - отказ пользователя от переключения в service mode
#               $? - ошибка проверки
main() {
    i18n::load
    check_unit
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
