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

# @type:        Orchestrator
# @description: Интерфейс управления состоянием UFW: показ текущих правил и выбор действия
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               >0 - ошибка в процессе
orchestrator::dispatch_logic() {
    ufw::log_active_ufw_rules
    
    # Потоковая обработка: генерация меню → отображение → выбор → выполнение
    # Используем tee для однократной генерации меню
    ufw::get_menu_items | tee >(ufw::display_menu) | ufw::select_action | ufw::execute_action
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
