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
source "${MODULES_DIR_PATH}/05-ufw-helpers.sh"

trap log_stop EXIT

orchestrator::run_ufw_module() {
    
    # вернет код 2 при выходе 0 [ufw::select_action->io::ask_value->return 2]
    if ufw::get_menu_items | tee >(ufw::display_menu) | ufw::select_action | ufw::execute_action; then
        log_success "Успешно [Code: $?]"
    else
        local exit_code=$?
        case "$exit_code" in
            2) log_info "Выход [Code: $exit_code]"; return "$exit_code" ;;
            *) log_error "Сбой в цепочке UFW [Code: $exit_code]"; return "$exit_code" ;;
        esac
    fi
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
        orchestrator::run_ufw_module
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
