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

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Инициирует немедленный откат через SIGUSR2 и ожидает завершения watchdog
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 откат выполнен, процесс заблокирован
auto::orchestrator::trigger_immediate_rollback() {
    log_info "$(_ "rollback.signal_usr2_sent")"
    kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
    while true; do sleep 1; done
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
}

# @type:        Orchestrator
# @description: Настраивает SSH и UFW с механизмом rollback
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно завершена настройка
#               2 выход по запросу пользователя
#               4 требуется предварительная настройка (SSH ключ)
#               $? код ошибки дочернего процесса
auto::network::run() {
    make_fifo_and_start_reader
    
    start_sync_rollback
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "full")
    stop_sync_rollback

    local port
    port=$(ssh::port::generate_free_random_port | tr -d '\0')

    ssh::log::guard_instructions "$port"

    printf '%s\0' "$port" | ssh::rule::reset_and_pass | ufw::rule::reset_and_pass | ssh::port::install_new

    if ufw::ping::is_configured; then
        ufw::ping::restore
    fi
    ufw::orchestrator::disable_ping
    ufw::status::force_enable
    permissions::rules::make_bsss_rules
    sys::service::restart

    if ! ssh::port::wait_for_up "$port"; then
        ssh::orchestrator::trigger_immediate_rollback
    fi

    log_actual_info
    common::log::current_config "^port"
    ssh::orchestrator::log_statuses
    ufw::orchestrator::log_statuses
    permissions::orchestrator::log_statuses

    log_actual_info "$(_ "auto.info.connect_instruction" "$port")"
    if io::ask_value "$(_ "common.confirm_connection" "connected" "0")" "" "^connected$" "connected" "^0$" >/dev/null; then
        rollback::orchestrator::watchdog_stop
    else
        auto::orchestrator::trigger_immediate_rollback
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
    )
    while true; do
        log_info "$(_ "common.menu_header")"
        for item in 1 2 3 4; do
            log_info_simple_tab "$item. ${items[item-1]}"
        done
        log_info_simple_tab "0. $(_ "common.exit")"
        selection=$(io::ask_value "$(_ "auto.menu.ask_items")" "" "^[1-4]( +[1-4])*$" "1-4" "^0$" | tr -d '\0') || return

        log_info "$(_ "auto.menu.selected")"
        for item in 1 2 3 4; do
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
        auto::install::check
        log_info "$(_ "auto.info.rollback_timer_activation" "$ROLLBACK_TIMER_SECONDS")"
        auto::network::run
    fi
    if auto::menu::is_selected "$selection" 2; then
        if ! ipv6::config::is_configured; then
            ipv6::config::create_bsss_file >/dev/null
            ipv6::reboot::mark_required
        fi
    fi
    if auto::menu::is_selected "$selection" 3; then
        if auto::upgrades::is_configured; then
            log_info "$(_ "auto.upgrades.already_configured")"
        else
            auto::upgrades::orchestrator::enable
        fi
    fi
    if auto::menu::is_selected "$selection" 4; then
        if ! swap::orchestrator::enable; then
            log_warn "$(_ "swap.warn.auto_setup_failed" "$SWAPFILE_PATH")"
        fi
    fi
    log_info "$(_ "common.success_changes_committed")"
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
    log_info "$(_ "auto.info.auto_setup_rules")"
    log_info_simple_tab "$(_ "auto.info.sshd_random_port")"
    log_info_simple_tab "$(_ "auto.info.sshd_deny_root")"
    log_info_simple_tab "$(_ "auto.info.sshd_deny_password")"
    log_info_simple_tab "$(_ "auto.info.ufw_disable_ping")"
    log_info_simple_tab "$(_ "auto.info.ufw_ssh_port_rule")"
    log_info_simple_tab "$(_ "auto.info.ufw_activation")"
    log_info_simple_tab "$(_ "auto.info.auto_upgrades")"
    log_info_simple_tab "$(_ "auto.info.ipv6_disable")"
    log_info_simple_tab "$(_ "auto.info.swap_enable")"
    log_info "$(_ "auto.info.logs_location" "$(readlink -f "${PROJECT_ROOT}/logs")")"
    local selection
    selection=$(auto::menu::select | tr -d '\0') || return
    auto::install::run "$selection"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
