#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Настраивает swap файл

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/swap.sh"

trap common::int::actions INT
trap common::exit::actions EXIT

# @type:        Orchestrator
# @description: Отобразить меню и диспетчеризовать выбор пользователя
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
swap::main::menu::dispatcher() {
    swap::log::disk_stats || true
    log_info "$(_ "common.menu_header")"
    swap::state::is_configured && \
        log_info_simple_tab "1. $(_ "swap.menu.item_disable")" || \
        log_info_simple_tab "1. $(_ "swap.menu.item_enable")"
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-1]$" "0-1" "^0$" | tr -d '\0') || return

    case "$menu_id" in
        1) swap::state::is_configured && swap::orchestrator::disable || swap::orchestrator::enable ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля swap
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
main() {
    i18n::load
    log_start
    swap::main::menu::dispatcher
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
