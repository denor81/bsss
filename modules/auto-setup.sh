#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Автоматическая настройка системы

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"
source "${PROJECT_ROOT}/modules/helpers/auto-upgrades.sh"
source "${PROJECT_ROOT}/modules/helpers/swap.sh"
source "${PROJECT_ROOT}/modules/helpers/ipv6.sh"
source "${PROJECT_ROOT}/modules/helpers/system-update.sh"
source "${PROJECT_ROOT}/modules/helpers/auto-setup.sh"

trap common::int::actions INT
trap 'exit 143' TERM
trap auto::rollback::on_exit EXIT
trap auto::rollback::completed SIGUSR1

# @type:        Orchestrator
# @description: При незавершенной настройке запускает полный откат и сохраняет код выхода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   $? код завершения автонастройки
auto::rollback::on_exit() {
    local rc=$?
    trap '' INT TERM SIGUSR1
    LOG_STRICT_MODE=false

    if [[ -n "$WATCHDOG_PID" ]]; then
        # || true: watchdog мог уже завершить откат по таймеру
        kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
        log_info "$(_ "rollback.signal_usr2_sent")"
        wait "$WATCHDOG_PID" 2>/dev/null || true
    fi

    # || true: ошибка очистки не должна подменять исходный код завершения
    printf '%s\0' "$WATCHDOG_FIFO" "$SYNC_FIFO" | sys::file::delete || true
    log_info "$(_ "common.exit_received" "$rc")"
    log_stop
    exit "$rc"
}

# @type:        Orchestrator
# @description: Завершает автонастройку после полного отката watchdog без повторного сигнала
# @stdin:       нет
# @stdout:      нет
# @exit_code:   3 выполнен откат
auto::rollback::completed() {
    WATCHDOG_PID=""
    common::rollback::stop_script_by_rollback_timer
}

# @type:        Orchestrator
# @description: Проверяет предварительные условия перед установкой
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 проверки пройдены успешно
#               4 требуется предварительная настройка (SSH ключ)
#               $? код ошибки дочернего процесса
auto::install::check() {
    user::info::block
    permissions::check::current_user # возможно прерывание кодом 4
    local current_conn_type
    current_conn_type=$(sys::user::get_auth_method | tr -d '\0')
    if [[ "$current_conn_type" != "key" ]]; then
        log_warn "$(_ "permissions.warn.cannot_determine_connection")"
        return 4
    fi
}

# @type:        Orchestrator
# @description: Проверяет зависимости выбранных действий до запуска watchdog
# @params:      selection Номера через пробел (string) без завершающего символа
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 зависимости доступны
#               4 требуется предварительная настройка
#               $? ошибка проверки
auto::selection::check() {
    local selection="$1"
    if auto::menu::is_selected "$selection" 2; then
        if ! auto::upgrades::is_installed; then
            log_warn "$(_ "common.install.not_installed" "unattended-upgrades")"
            return 4
        fi
    fi
    if auto::menu::is_selected "$selection" 5 && ! auto::menu::is_selected "$selection" 4; then
        ufw status >/dev/null
        if ! ufw::status::is_active; then
            log_warn "$(_ "auto.warning.ping_requires_ufw")"
            return 4
        fi
    fi
}

# @type:        Validator
# @description: Проверяет наличие пункта в выбранных номерах
# @params:      selection Номера через пробел (string) без завершающего символа
#               item Номер пункта (num) без завершающего символа
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 пункт выбран
#               1 пункт не выбран
auto::menu::is_selected() {
    [[ " $1 " == *" $2 "* ]]
}

# @type:        Source
# @description: Показывает меню и запрашивает подтверждение выбранных пунктов
# @stdin:       нет (ввод через TTY)
# @stdout:      selection\0
# @exit_code:   0 выбор подтвержден
#               2 отмена пользователем
auto::menu::select() {
    local selection item
    local -a items=(
        "$(_ "auto.menu.item_1")"
        "$(_ "auto.menu.item_2")"
        "$(_ "auto.menu.item_3")"
        "$(_ "auto.menu.item_4")"
        "$(_ "auto.menu.item_5")"
        "$(_ "auto.menu.item_6")"
        "$(_ "auto.menu.item_7" "$SWAPFILE_SIZE")"
        "$(_ "auto.menu.item_8")"
    )
    while true; do
        log_info "$(_ "common.menu_header")"
        for item in 1 2 3 4 5 6 7 8; do
            log_info_simple_tab "$item. ${items[item-1]}"
        done
        log_info_simple_tab "0. $(_ "common.exit")"
        selection=$(io::ask_value "$(_ "auto.menu.ask_items")" "" "^[1-8]( +[1-8])*$" "1-8" "^0$" | tr -d '\0') || return

        log_info "$(_ "auto.menu.selected")"
        for item in 1 2 3 4 5 6 7 8; do
            if auto::menu::is_selected "$selection" "$item"; then
                log_info_simple_tab "$item. ${items[item-1]}"
            fi
        done
        if io::confirm_action; then
            printf '%s\0' "$selection"
            return 0
        fi
    done
}

# @type:        Orchestrator
# @description: Выполняет выбранные действия в фиксированном порядке
# @params:      selection Номера через пробел (string) без завершающего символа
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 настройка завершена
#               $? код ошибки выбранного действия
auto::install::run() {
    local selection="$1"
    if auto::menu::is_selected "$selection" 1; then
        sys::update::get_command "auto" | sys::update::execute
    fi
    if auto::menu::is_selected "$selection" 2; then
        if auto::upgrades::is_configured; then
            log_info "$(_ "auto.upgrades.already_configured")"
        else
            auto::upgrades::orchestrator::enable
        fi
    fi
    if auto::menu::is_selected "$selection" 3; then
        auto::ssh::configure
    fi
    if auto::menu::is_selected "$selection" 4; then
        auto::ufw::enable
    fi
    if auto::menu::is_selected "$selection" 5; then
        auto::ping::disable
    fi
    if auto::menu::is_selected "$selection" 6; then
        auto::permissions::configure
    fi
    if auto::menu::is_selected "$selection" 7; then
        swap::orchestrator::enable
    fi
    if auto::menu::is_selected "$selection" 8; then
        if ipv6::config::is_configured; then
            log_info "$(_ "auto.info.already_configured" "$(_ "module.ipv6.name")")"
        else
            ipv6::config::create_bsss_file >/dev/null
            ipv6::reboot::mark_required
        fi
    fi
}

# @type:        Orchestrator
# @description: Запускает модуль автоматической настройки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешное завершение
#               2 выход по запросу пользователя
#               $? код ошибки дочернего процесса
main() {
    i18n::load
    log_start
    auto::install::check
    log_info "$(_ "auto.info.auto_setup_rules")"
    log_info "$(_ "auto.info.rollback_timer_activation" "$AUTO_SETUP_ROLLBACK_TIMER_SECONDS")"
    log_info "$(_ "auto.info.logs_location" "$(readlink -f "${PROJECT_ROOT}/logs")")"
    local selection ports
    selection=$(auto::menu::select | tr -d '\0')
    auto::selection::check "$selection"

    make_fifo_and_start_reader
    start_sync_rollback
    # Прямой вызов сохраняет watchdog дочерним процессом: EXIT сможет дождаться отката.
    rollback::orchestrator::watchdog_start "full" "" "$AUTO_SETUP_ROLLBACK_TIMER_SECONDS" >/dev/null
    WATCHDOG_PID=$!
    stop_sync_rollback

    auto::install::run "$selection"

    log_actual_info
    common::log::current_config "^port"
    ssh::orchestrator::log_statuses
    ufw::orchestrator::log_statuses
    permissions::orchestrator::log_statuses
    ports=$(ssh::port::get_from_ss | tr '\0' ',' | sed 's/,$//')
    log_actual_info "$(_ "auto.info.connect_instruction" "$ports")"
    io::ask_value "$(_ "common.confirm_connection" "connected" "0")" "" "^connected$" "connected" "^0$" >/dev/null

    rollback::orchestrator::watchdog_stop
    WATCHDOG_PID=""
    log_info "$(_ "common.success_changes_committed")"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
