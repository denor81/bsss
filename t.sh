#!/usr/bin/env bash
# Проверяет SSH порт
# MODULE_TYPE: check



set -Eeuo pipefail


ufw::menu::get_items() {
    ufw::rule::is_active && printf '%s|%s\0' "1" "Выключить UFW" || printf '%s|%s\0' "1" "Включить UFW"
    ufw::ping::is_configured && printf '%s|%s\0' "2" "Ping будет включен [ACCEPT] [По умолчанию]" || printf '%s|%s\0' "2" "Ping будет отключен [DROP]"
    printf '%s|%s\0' "0" "Выход"
}

# @type:        Sink
# @description: Отображает пункты меню пользователю (вывод только в stderr)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::menu::display() {
    local id
    local text

    log::draw_lite_border

    ufw::log::status
    ufw::log::rules
    ufw::log::ping_status

    log_info "Доступные действия:"

    while IFS='|' read -r -d '' id text || break; do
        log_info_simple_tab "$id. $text"
    done < <(ufw::menu::get_items)

    log::draw_lite_border
}

ufw::menu::count_items() {
    ufw::menu::get_items | grep -cz '^'
}

ufw::menu::count_items | cat -A