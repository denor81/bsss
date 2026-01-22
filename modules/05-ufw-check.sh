#!/usr/bin/env bash
# Установлен ufw или нет
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/common-helpers.sh"
source "${PROJECT_ROOT}/modules/05-ufw-helpers.sh"

# @type:        Orchestrator
# @description: Проверяет наличие UFW и устанавливает при необходимости
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - UFW установлен или уже был установлен
#               1 - ошибка установки или отказ от установки
check() {
    if command -v ufw > /dev/null 2>&1; then
        ufw::log_status
        ufw::log_active_ufw_rules
    else
        log_error "UFW не установлен"
        if io::confirm_action "Установить UFW сейчас? [apt update && apt install ufw -y]" || return; then
            if ! (apt update && apt install ufw -y); then
                log_error "Ошибка при установке UFW"
                return 1
            else
                if command -v ufw > /dev/null 2>&1; then
                    log_info "UFW успешно установлен"
                else
                    log_info "UFW установлен - перезапустите скрипт"
                    return 1
                fi
            fi
        fi
    fi


}

main() {
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi