#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# @type:        Source
# @description: Генерирует список доступных пунктов меню на основе текущего состояния
# @params:      нет
# @stdin:       нет
# @stdout:      id|text\0 (0..N)
# @exit_code:   0 - успешно
ufw::get_menu_items() {
    local id=1
    
    # Пункт для переключения UFW
    if ufw::is_active; then
        printf '%s|%s\0' "$id" "Выключить UFW"
    else
        printf '%s|%s\0' "$id" "Включить UFW"
    fi
    id=$((id + 1))
}

# @type:        Sink
# @description: Отображает пункты меню пользователю (вывод только в stderr)
# @params:      нет
# @stdin:       id|text\0 (0..N)
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::display_menu() {
    local id_text
    local id
    local text
    
    log::draw_lite_border
    log_info "Доступные действия:"
    
    while IFS='|' read -r -d '' id_text || break; do
        id="${id_text%%|*}"
        text="${id_text#*|}"
        log_info_simple_tab "$id. $text"
    done
    
    log_info_simple_tab "0. Выход"
    log::draw_lite_border
}

# @type:        Filter
# @description: Запрашивает выбор пользователя и возвращает выбранный ID
# @params:      нет
# @stdin:       id|text\0 (0..N)
# @stdout:      id\0 (0..1) - выбранный ID или 0 (выход)
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
ufw::select_action() {
    local -a menu_items=()
    local max_id=0
    local id_text
    
    # Читаем все пункты в массив
    while IFS= read -r -d '' id_text || break; do
        menu_items+=("$id_text")
        local id="${id_text%%|*}"
        (( id > max_id )) && max_id=$id
    done
    
    # Формируем паттерн для валидации
    local pattern="^[0-$max_id]$"
    
    # Запрашиваем выбор
    local selection
    selection=$(io::ask_value "Выберите действие" "" "$pattern" "0-$max_id" | tr -d '\0') || return
    
    # Если выбран 0 - выход
    if [[ "$selection" == "0" ]]; then
        log_info "Выход из меню"
        return 2
    fi
    
    # Выводим выбранный ID
    printf '%s\0' "$selection"
}

# @type:        Orchestrator
# @description: Выполняет выбранное действие на основе ID
# @params:      нет
# @stdin:       id\0 (0..1)
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от действия
ufw::execute_action() {
    local action_id
    read -r -d '' action_id
    
    case "$action_id" in
        1) ufw::toggle ;;
    esac
}

# @type:        Sink
# @description: Переключает состояние UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
ufw::toggle() {
    if ufw::is_active; then
        ufw::force_disable
    else
        ufw::enable
    fi
}
