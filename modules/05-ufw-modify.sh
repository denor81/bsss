#!/usr/bin/env bash
# Изменяет состояние UFW
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"
source "${MODULES_DIR_PATH}/../lib/user_confirmation.sh"
source "${MODULES_DIR_PATH}/common-helpers.sh"

trap log_stop EXIT

# @type:        Orchestrator
# @description: Интерфейс управления состоянием UFW: показ текущих правил и выбор действия
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               >0 - ошибка в процессе
orchestrator::dispatch_logic() {
    ufw::log_active_ufw_rules
    log_info_simple_tab "1. Включить UFW"
    log_info_simple_tab "2. Деактивировать UFW"

    local user_action
    user_action=$(io::ask_value "Выберите действие" "" "^[12]$" "1/2" | tr -d '\0') || return

    case "$user_action" in
        1) ufw::enable ;;
        2) ufw::force_disable ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля изменения состояния UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    log_start

    if io::confirm_action "Изменить состояние UFW?"; then
        orchestrator::dispatch_logic
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
