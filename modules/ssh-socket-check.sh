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

# @type:        Filter
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
