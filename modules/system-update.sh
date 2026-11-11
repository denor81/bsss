#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Обновляет системные пакеты

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/system-update.sh"

trap log_stop EXIT

# @type:        Orchestrator
# @description: Confirms package commands and logs disk usage around each selected stage
# @params:      cleanup Optional cleanup mode (string), without terminator
# @stdin:       User confirmation from TTY
# @stdout:      None
# @exit_code:   0 success
#               1 update or cleanup failure
#               2 user cancellation
#               $? snapshot, formatting, or logging failure
sys::update::orchestrator() {
    local update_cmd cleanup_cmd=""
    local stats total used available initial_available updated_available
    update_cmd=$(sys::update::get_command | tr -d '\0')
    if [[ "${1:-}" == "cleanup" ]]; then
        cleanup_cmd=$(sys::update::get_command "cleanup" | tr -d '\0')
        io::confirm_action "$(_ "system.update.cleanup_confirm" "$update_cmd && $cleanup_cmd")"
    else
        io::confirm_action "$(_ "system.update.confirm" "$update_cmd")"
    fi

    stats=$(sys::update::get_disk_stats | tr -d '\0')
    read -r total used initial_available <<< "$stats"
    sys::update::log_disk "before" "$total" "$used" "$initial_available"

    printf '%s\0' "$update_cmd" | sys::update::execute
    stats=$(sys::update::get_disk_stats | tr -d '\0')
    read -r total used updated_available <<< "$stats"
    sys::update::log_disk "after_update" "$total" "$used" "$updated_available"
    sys::update::log_delta "$initial_available" "$updated_available" "total"

    if [[ -n "$cleanup_cmd" ]]; then
        printf '%s\0' "$cleanup_cmd" | sys::update::execute "cleanup"
        stats=$(sys::update::get_disk_stats | tr -d '\0')
        read -r total used available <<< "$stats"
        sys::update::log_disk "after_cleanup" "$total" "$used" "$available"
        sys::update::log_delta "$updated_available" "$available" "cleanup"
        sys::update::log_delta "$initial_available" "$available" "total"
    fi
}

# @type:        Orchestrator
# @description: Displays update options and dispatches the selected action
# @stdin:       User selection from TTY
# @stdout:      None
# @exit_code:   0 success
#               1 update or cleanup failure
#               2 user cancellation
#               $? snapshot, formatting, or logging failure
sys::update::menu() {
    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "1. $(_ "system.update.menu.cleanup")"
    log_info_simple_tab "2. $(_ "system.update.menu.only_update")"
    log_info_simple_tab "0. $(_ "system.update.menu.back")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-2]$" "0-2" "^0$" | tr -d '\0') || return
    case "$menu_id" in
        1) sys::update::orchestrator "cleanup" ;;
        2) sys::update::orchestrator ;;
    esac
}

# @type:        Orchestrator
# @description: Запускает основную точку входа модуля обновления системы
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
main() {
    i18n::load
    log_start
    sys::update::menu
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
