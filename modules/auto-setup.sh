#!/usr/bin/env bash
# Автоматическая настройка системы

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

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
# @description: Инициирует немедленный откат через SIGUSR2 и ожидает завершения watchdog
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - откат выполнен, процесс заблокирован
auto::orchestrator::trigger_immediate_rollback() {
    kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
    while true; do sleep 1; done
}

# @type:        Orchestrator
# @description: Выполняет автоматическую настройку с механизмом rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
auto::install::run() {
    permissions::check::current_user || return

    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "full")

    local port
    port=$(ssh::port::generate_free_random_port | tr -d '\0')

    ssh::log::guard_instructions "$port"

    printf '%s\0' "$port" | ssh::rule::reset_and_pass | ufw::rule::reset_and_pass | ssh::port::install_new

    ufw::orchestrator::disable_ping
    ufw::status::force_enable
    permissions::rules::make_bsss_rules
    sys::service::restart

    log_actual_info
    ssh::orchestrator::log_statuses
    ufw::orchestrator::log_statuses
    permissions::orchestrator::log_statuses

    if io::ask_value "$(_ "common.confirm_connection" "connected" "0")" "" "^connected$" "connected" "0" >/dev/null; then
        rollback::orchestrator::watchdog_stop "$WATCHDOG_PID"
        log_info "$(_ "common.success_changes_committed")"
    else
        auto::orchestrator::trigger_immediate_rollback
    fi
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля автоматической настройки
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    i18n::load
    log_start
    auto::install::run
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
