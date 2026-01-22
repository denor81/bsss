#!/usr/bin/env bash
# Проверяет SSH порт
# MODULE_TYPE: check



set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"
source "${PROJECT_ROOT}/lib/logging.sh"

ufw::is_active() {
    ufw status | grep -q "^Status: active"
}

ufw::enable_toggle_text() {
    if ufw::is_active; then
        printf 'Отключить UFW\0'
    else
        printf 'Включить UFW\0'
    fi
}

ufw::ping_toggle_text() {
    printf 'Разрешить пинги ICMP\0'
}

ufw::get_menu_config() {
    # Очищаем и объявляем мапу (нужен Bash 4+)
    unset MENU_ACTIONS
    declare -gA MENU_ACTIONS

    # Формируем пункты динамически
    MENU_ACTIONS[1]="toggle_ufw:$(ufw::enable_toggle_text | tr -d '\0')"
    MENU_ACTIONS[2]="toggle_ping:$(ufw::ping_toggle_text | tr -d '\0')"
    # Можно легко добавить 3-й пункт
}

ufw::display_menu() {
    ufw::get_menu_config
    # log::draw_lite_border
    # log_info "Доступные действия:"
    
    # echo "${!MENU_ACTIONS[@]@Q}"
    printf '%s\n' "${MENU_ACTIONS[@]}" | sort -n | while IFS=':' read -r key label; do
        log_info_simple_tab "$key. $label"
    done
    # printf '%s' "${!MENU_ACTIONS[@]}"
    # Итерируемся по отсортированным ключам
    # for key in $(echo "${!MENU_ACTIONS[@]}" | tr ' ' '\n' | sort -n); do
    #     printf '%s' "${key@Q}"
    #     local label="${MENU_ACTIONS[$key]#*:}" # Берем текст после двоеточия
    #     log_info_simple_tab "$key. $label"
    # done
    # log_info_simple_tab "0. Выход"
    # log::draw_lite_border
}

ufw::display_menu