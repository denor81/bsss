#!/usr/bin/env bash
# Проверяет SSH порт
# MODULE_TYPE: check

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"
source "${MODULES_DIR_PATH}/common-helpers.sh"
source "${MODULES_DIR_PATH}/04-ssh-port-helpers.sh"

check() {
    local active_ports
    active_ports=$(_get_active_ssh_ports) # Здесь скрипт упадет, если функция вернет 1
    log_info "Активные SSH порты [ss -nlptu]: ${active_ports}"
    
    local config_ports
    config_ports=$(_get_all_config_ports)
    if [[ -n "$config_ports" ]]; then
        log_info "Активные SSH настройки в /etc/ssh: ${config_ports}"
    else
        log_info "Нет активных настроек [Port] в файле $SSH_CONFIG_FILE и в директории $SSH_CONFIGD_DIR";
    fi
}


main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
