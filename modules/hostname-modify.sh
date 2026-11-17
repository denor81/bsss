#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Configures the server hostname

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/hostname.sh"

trap common::int::actions INT
trap common::exit::actions EXIT

# @type:        Orchestrator
# @description: Displays hostname actions and dispatches the selected action
# @stdin:       User input from the controlling terminal
# @stdout:      None
# @exit_code:   0 action completed
#               1 hostname configuration failed
#               2 cancelled by user
hostname::main::menu::dispatcher() {
    hostname::log::status
    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "1. $(_ "hostname.menu.item_change")"

    local pattern="^[0-1]$"
    local hint="0-1"
    if hostname::state::is_configured; then
        log_info_simple_tab "2. $(_ "hostname.menu.item_restore")"
        pattern="^[0-2]$"
        hint="0-2"
    fi
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "$pattern" "$hint" "^0$" | tr -d '\0') || return

    case "$menu_id" in
        1)
            local new_hostname
            new_hostname=$(hostname::ui::get_new | tr -d '\0') || return
            log_info "$(_ "hostname.info.change_summary" "$(hostname::name::get_current)" "$new_hostname")"
            io::confirm_action "$(_ "hostname.confirm.change")"
            hostname::orchestrator::configure "$new_hostname"
            ;;
        2)
            io::confirm_action "$(_ "hostname.confirm.restore")"
            hostname::orchestrator::restore
            ;;
    esac
}

# @type:        Orchestrator
# @description: Runs the hostname modification module
# @stdin:       User input from the controlling terminal
# @stdout:      None
# @exit_code:   0 module completed
#               1 hostname configuration failed
#               2 cancelled by user
main() {
    i18n::load
    log_start
    hostname::main::menu::dispatcher
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
