#!/usr/bin/env bash
# Изменяет состояние UFW

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Проверяет требования для запуска UFW модуля
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - требования выполнены
#               4 - требования не выполнены
ufw::rule::check_requirements() {
    if ufw::rule::has_any_bsss; then
        return
    fi

    if ufw::status::is_active; then
        log_info "$(_ "ufw.info.no_rules_but_active")"
        return
    else
        log_warn "$(_ "ufw.warning.continue_without_rules")"
        log_info "$(_ "ufw.warning.add_ssh_first")"
        log_bold_info "$(_ "common.helpers.ufw.rules.sync")"
        log_bold_info "$(_ "common.helpers.ufw.rules.delete_warning")"
        return 4
    fi
}

# @type:        Orchestrator
# @description: Переключает состояние UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
ufw::toggle::status() {
    if ufw::status::is_active; then
        ufw::status::force_disable
    else
        ufw::safe::force_enable
    fi
}

ufw::status::force_enable() {
    if ! ufw --force enable >/dev/null 2>&1; then
        rollback::orchestrator::immediate_usr2
        log_error "$(_ "ufw.error.enable_failed")"
        return 1
    else
        log_info "$(_ "ufw.success.enabled")"
    fi
}

# @type:        Orchestrator
# @description: Активирует UFW с watchdog и подтверждением подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отменено пользователем (подтверждение не получено)
#               1 - ошибка активации UFW
ufw::safe::force_enable() {
    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ufw")
    ufw::log::rollback::instructions

    ufw::force::enable

    log_actual_info
    ufw::orchestrator::log_statuses

    if io::ask_value "$(_ "common.confirm_connection" "connected" "0")" "" "^connected$" "connected" "0" >/dev/null; then
        log_info "$(_ "common.success_changes_committed")"
        rollback::orchestrator::watchdog_stop
    else
        rollback::orchestrator::immediate_usr2
    fi
}

# @type:        Sink
# @description: Отображает инструкции пользователю для проверки подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log::rollback::instructions() {
    log_attention "$(_ "common.warning.dont_close_terminal")"
    log_attention "$(_ "ufw.rollback.test_access")"
}

# @type:        Orchestrator
# @description: Переключает состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
ufw::toggle::ping() {
    if ufw::ping::is_configured; then
        ufw::ping::restore
    else
        ufw::orchestrator::disable_ping
    fi
    ufw::status::reload
}

ufw::main::menu::dispatcher() {
    log_info "$(_ "common.menu_header")"
    ufw::status::is_active && log_info_simple_tab "1. $(_ "ufw.menu.item_disable")" || log_info_simple_tab "1. $(_ "ufw.menu.item_enable")"
    ufw::ping::is_configured && log_info_simple_tab "2. $(_ "ufw.menu.item_ping_enable")" || log_info_simple_tab "2. $(_ "ufw.menu.item_ping_disable")"
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-2]$" "0-2" "0" | tr -d '\0') || return

    # Валидация производится в io::ask_value - по этому нет пункта case отлавливающего неверный выбор
    case "$menu_id" in
        1) ufw::toggle::status ;;
        2) ufw::toggle::ping ;;
    esac
}

ufw::orchestrator::run_module() {
    ufw::main::menu::dispatcher
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля изменения состояния UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    i18n::load
    log_start

    ufw::rule::check_requirements

    ufw::orchestrator::run_module
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
