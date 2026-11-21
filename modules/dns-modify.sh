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
source "${PROJECT_ROOT}/modules/helpers/dns/facade.sh"

trap dns::prepare::on_signal INT TERM
trap common::exit::actions EXIT

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
    local mode status
    if mode=$(dns::mode::get | tr -d '\0'); then
        :
    else
        status=$?
        (( status == 4 )) || return "$status"
    fi

    dns::presentation::status
    if [[ "$mode" == "interrupted" ]]; then
        log_warn "$(_ "dns.prepare.interrupted")"
        log_info "$(_ "common.menu_header")"
        log_info_simple_tab "1. $(_ "dns.menu.recover")"
        log_info_simple_tab "0. $(_ "common.exit")"

        io::ask_value "$(_ "common.ask_select_action")" "" "^[0-1]$" "0-1" "^0$" >/dev/null || return
        io::confirm_action "$(_ "dns.confirm.recover")"
        dns::presentation::execute dns::orchestrator::recover || return
        log_success "$(_ "dns.prepare.recovery_complete")"
        dns::presentation::status
        return
    fi

    if [[ "$mode" == "networkd-direct" ]]; then
        if dns::check::compatibility "$mode" >/dev/null; then
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
            dns::presentation::execute dns::orchestrator::remove || return
            log_success "$(_ "dns.rollback.new_config_removed")"
            dns::presentation::status
            return
            ;;
    esac

    if [[ "$mode" == "networkd-direct" ]]; then
        io::confirm_action "$(_ "dns.confirm.prepare" "$(dns::presentation::profile_name "$profile")")"
    else
        io::confirm_action "$(_ "dns.confirm.apply" "$(dns::presentation::profile_name "$profile")")"
    fi
    dns::presentation::execute dns::orchestrator::apply "$mode" "$profile" || return
    if [[ "$mode" == "networkd-direct" ]]; then
        log_success "$(_ "dns.prepare.success")"
    else
        log_success "$(_ "dns.config.installed" "$BSSS_DNS_CONFIG_FILE")"
    fi
    dns::presentation::status
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
