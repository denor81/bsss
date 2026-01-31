#!/usr/bin/env bash
# Проверяет режим запуска SSH (socket vs service)
# MODULE_ORDER: 30
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-socket.sh"

check_unit() {
    if ! sys::ssh::unit_exists "ssh.service"; then
        log_error "Юнит ssh.service не установлен [ssh.service]"
        log_info_simple_tab "Скрипт ${UTIL_NAME^^} предназначен для запуска на сервере с усановленным ssh.service юнитом"
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
check() {
    if ssh::socket::is_already_configured || return; then
        log_info "SSH настроен корректно [ssh.service]"
        return
    fi

    log_error "SSH настроен в режиме [ssh.socket], в этом режиме наблюдаются проблемы с поднятием порта"
    log_info "Для работы скрипта требуется переключение SSH в Service Mode [ssh.service]"
    io::confirm_action "Переключить SSH в Service Mode?"
    ssh::socket::force_service_mode
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
    check_unit
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
