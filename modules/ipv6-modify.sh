#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Настраивает IPv6 через grub.d

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ipv6.sh"

trap common::int::actions INT
trap common::exit::actions EXIT

# @type:        Orchestrator
# @description: Отобразить меню и диспетчеризовать выбор пользователя
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
ipv6::main::menu::dispatcher() {
    log_info "$(_ "common.menu_header")"
    ipv6::config::is_configured && \
        log_info_simple_tab "1. $(_ "ipv6.menu.item_enable")" || \
        log_info_simple_tab "1. $(_ "ipv6.menu.item_disable")"
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-1]$" "0-1" "^0$" | tr -d '\0') || return

    case "$menu_id" in
        1)
            if ipv6::config::is_configured; then
                ipv6::config::remove_bsss_files
                ipv6::reboot::mark_required
                return
            fi

            ipv6::config::create_bsss_file >/dev/null
            ipv6::reboot::mark_required
            ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля IPv6
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
main() {
    i18n::load
    log_start
    ipv6::main::menu::dispatcher
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
