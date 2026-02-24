#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Полный откат всех настроек BSSS

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Запускает полный откат всех настроек BSSS с подтверждением
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно завершен
#               1 критическая ошибка
#               2 отмена пользователем
full_rollback::orchestrator::run_module() {
    log_info "$(_ "full_rollback.info.full_rollback_warning")"

    io::confirm_action

    make_fifo_and_start_reader

    start_sync_rollback
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "full" "quiet")
    stop_sync_rollback

    ssh::orchestrator::trigger_immediate_rollback

}

# @type:        Orchestrator
# @description: Основная точка входа для модуля полного отката
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно завершен
#               1 критическая ошибка
#               2 отмена пользователем
main() {
    i18n::load
    log_start
    full_rollback::orchestrator::run_module
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
