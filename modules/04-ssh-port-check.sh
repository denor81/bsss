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

check_active_ports() {
    local active_ports=""

    # Ожидаем получение активных портов, если портов нет, то это значит, что не можем получить данные из ss -nlptu и продолжение не возможно
    active_ports=$(_get_active_ssh_ports) || return 1 # Пишем в переменну, что бы в случае > 0 остановить скрипт
    log_info "Активные SSH порты [ss -nlptu]: ${active_ports}"
}

# Ищем все порты в файлах конфигурации /etc/ssh...
check_config_ports() {
    local config_ports=""

    # ожидаем получить список портов из каталога настроек SSH, если пусто, то портов нет, но скрипт может быть продолжен
    config_ports=$(_get_all_config_ports_by_mask "$SSH_CONFIG_FILE" "$SSH_CONFIG_FILE_MASK") || return 1

    if [[ -n "$config_ports" ]]; then
        log_info "Активные SSH настройки в /etc/ssh: ${config_ports}"
    else
        log_info "Нет активных настроек [Port] [$SSH_CONFIG_FILE и ${SSH_CONFIGD_DIR}/]"
    fi
}

# Есть ли уже конфигурация bsss?
check_bsss_configs() {
    local raw_paths=""
    local -a paths_with_ports=()

    raw_paths=$(_get_all_files_by_mask_with_port "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK") || return 1

    if [[ -n "$raw_paths" ]]; then
        mapfile -t paths_with_ports < <(printf '%s' "$raw_paths")
    fi
    
    if (( ${#paths_with_ports[@]} > 0 )); then
        log_success "Найден конфиг файл [${UTIL_NAME^^}]: $(printf '%s ' "${paths_with_ports[@]//$'\t'/ }")"
    else
        log_info "Нет активных настроек [${UTIL_NAME^^}] [${SSH_CONFIGD_DIR}/]"
    fi
}

check() {
    check_active_ports
    check_config_ports
    check_bsss_configs
}


main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
