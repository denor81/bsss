#!/usr/bin/env bash
# Изменяет состояние UFW
# MODULE_ORDER: 80
# MODULE_TYPE: modify
# MODULE_NAME: Настройка брандмауэра UFW

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Запускает модуль UFW с механизмом rollback только при включении UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ufw::orchestrator::run_module() {
    #
    # Через пайп и сабшелл не получается потому что в get_user_choice есть read и он в случае пайпа запускается с иным PID
    # ufw::menu::get_user_choice | ufw::orchestrator::dispatch_logic
    #

    ufw::menu::display

    local menu_id
    menu_id=$(ufw::menu::get_user_choice | tr -d '\0') || return
    # Запускаем в текущем процессе, что бы корректно завершать read при получении сигнала отката SIGUSR1
    ufw::orchestrator::dispatch_logic "$menu_id"
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля изменения состояния UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отказ пользователя
#               4 - требования не выполнены
#               130 - прерывание по Ctrl+C
#               $? - ошибка выполнения модулей
main() {
    log_start

    io::confirm_action "Изменить состояние UFW?" || return

    ufw::rule::check_requirements || return

    ufw::orchestrator::run_module
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
