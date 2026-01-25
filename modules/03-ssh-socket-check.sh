#!/usr/bin/env bash
# Проверяет режим запуска SSH (socket vs service)
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/03-ssh-socket-helpers.sh"

# @type:        Orchestrator
# @description: Настраивает SSH в service режим, если это необходимо
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - режим корректен или успешно переключен
#               1 - ошибка в ssh::socket::force_service_mode
check() {
    if ssh::socket::is_already_configured; then
        log_info "SSH настроен корректно [ssh.service]"
        return 0
    fi

    log_error "SSH настроен в режиме [ssh.socket], в этом режиме наблюдаются проблемы с поднятием порта"
    log_info "Для работы скрипта требуется переключение SSH в Service Mode [ssh.service]"
    io::confirm_action "Переключить SSH в Service Mode?"
    ssh::socket::force_service_mode
}

main() {
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
