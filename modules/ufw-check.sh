#!/usr/bin/env bash
# Установлен ufw или нет

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"

# @type:        Orchestrator
# @description: Проверять наличие UFW и устанавливать при необходимости
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 UFW установлен или уже был установлен
#               1 ошибка установки UFW
#               2 отказ пользователя от установки
check() {
    if command -v ufw > /dev/null 2>&1; then
        ufw::log::status
        ufw::log::rules
        ufw::log::ping_status
    else
        log_error "$(_ "common.install.not_installed" "UFW")"
        if io::confirm_action "$(_ "common.install.confirm" "UFW")" || return; then
            if ! (apt-get update && apt-get install -y ufw); then
                log_error "$(_ "common.install.error" "UFW")"
                return 1
            else
                if command -v ufw > /dev/null 2>&1; then
                    log_info "$(_ "common.install.success" "UFW")"
                else
                    log_info "$(_ "ufw.check.installed_restart")"
                    return 1
                fi
            fi
        fi
    fi


}

# @type:        Orchestrator
# @description: Запускать модуль проверки UFW
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 проверка прошла успешно
#               1 ошибка установки UFW
#               2 отказ пользователя от установки
#               $? другие коды
main() {
    i18n::load
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi