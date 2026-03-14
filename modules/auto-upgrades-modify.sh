#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Настраивает автообновления и автоперезагрузку

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/auto-upgrades.sh"

trap common::int::actions INT
trap common::exit::actions EXIT

# @type:        Orchestrator
# @description: Отобразить меню и диспетчеризовать выбор пользователя
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
auto::upgrades::main::menu::dispatcher() {
    log_info "$(_ "common.menu_header")"
    auto::upgrades::is_configured && \
        log_info_simple_tab "1. $(_ "auto.upgrades.menu.item_disable")" || \
        log_info_simple_tab "1. $(_ "auto.upgrades.menu.item_enable")"
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-1]$" "0-1" "^0$" | tr -d '\0') || return

    # Валидация производится в io::ask_value - по этому нет пункта case отлавливающего неверный выбор
    case "$menu_id" in
        1) auto::upgrades::is_configured && auto::upgrades::orchestrator::disable || auto::upgrades::orchestrator::enable ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля автообновлений
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка настройки
main() {
    i18n::load
    log_start
    auto::upgrades::main::menu::dispatcher
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
