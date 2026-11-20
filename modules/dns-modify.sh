#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Configures strict DNS-over-TLS through systemd-resolved

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/dns.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Displays DNS actions and dispatches the selected action
# @stdin:       User input from the controlling terminal
# @stdout:      None
# @exit_code:   0 action completed
#               1 critical failure
#               2 cancelled by user
#               3 watchdog rollback completed
#               4 preconfiguration required
dns::main::menu() {
    local mode
    mode=$(dns::resolver::get_mode | tr -d '\0')

    dns::log::status
    if [[ "$mode" == "interrupted" ]]; then
        log_warn "$(_ "dns.prepare.interrupted")"
        log_info "$(_ "common.menu_header")"
        log_info_simple_tab "1. $(_ "dns.menu.recover")"
        log_info_simple_tab "0. $(_ "common.exit")"

        local recovery_rc
        io::ask_value "$(_ "common.ask_select_action")" "" "^[0-1]$" "0-1" "^0$" >/dev/null || return
        io::confirm_action "$(_ "dns.confirm.recover")"
        dns::prepare::recover || {
            recovery_rc=$?
            (( recovery_rc != 4 )) || log_warn "$(_ "dns.prepare.foreign_state" "$BSSS_STATE_DIR")"
            return "$recovery_rc"
        }
        return
    fi

    if [[ "$mode" == "networkd-direct" ]]; then
        if dns::prepare::os_is_supported; then
            log_warn "$(_ "dns.prepare.available")"
        else
            log_warn "$(_ "dns.prepare.unsupported_release" "$DNS_BOOTSTRAP_SUPPORTED_UBUNTU_VERSIONS")"
        fi
    fi
    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "1. $(_ "dns.menu.google_cloudflare")"
    log_info_simple_tab "2. $(_ "dns.menu.yandex_google")"

    local pattern="^[0-2]$"
    local hint="0-2"
    if dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
        log_info_simple_tab "3. $(_ "dns.menu.remove")"
        pattern="^[0-3]$"
        hint="0-3"
    fi
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id profile
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "$pattern" "$hint" "^0$" | tr -d '\0') || return

    case "$menu_id" in
        1) profile="$DNS_PROFILE_GOOGLE_CLOUDFLARE" ;;
        2) profile="$DNS_PROFILE_YANDEX_GOOGLE" ;;
        3)
            io::confirm_action "$(_ "dns.confirm.remove")"
            dns::transaction::remove
            return
            ;;
    esac

    if [[ "$mode" == "networkd-direct" ]]; then
        io::confirm_action "$(_ "dns.confirm.prepare" "$(dns::profile::get_name "$profile")")"
        dns::prepare::run "$profile"
    else
        io::confirm_action "$(_ "dns.confirm.apply" "$(dns::profile::get_name "$profile")")"
        dns::transaction::apply "$profile"
    fi
}

# @type:        Orchestrator
# @description: Runs the DNS-over-TLS modification module
# @stdin:       User input from the controlling terminal
# @stdout:      None
# @exit_code:   0 module completed
#               1 critical failure
#               2 cancelled by user
#               3 watchdog rollback completed
#               4 preconfiguration required
main() {
    i18n::load
    log_start
    dns::main::menu
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
