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

    # Пункт для управления PING
    if ufw::ping::is_configured; then
        printf '%s|%s\0' "$id" "Вернуть настройки PING по умолчанию"
    else
        printf '%s|%s\0' "$id" "Отключить пинг через UFW"
    fi
}

# @type:        Sink
# @description: Отображает пункты меню пользователю (вывод только в stderr)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::display_menu() {
    local id_text
    local id
    local text

    log::draw_lite_border
    ufw::log_active_ufw_rules
    log_info "Доступные действия:"

    while IFS='|' read -r -d '' id_text || break; do
        id="${id_text%%|*}"
        text="${id_text#*|}"
        log_info_simple_tab "$id. $text"
    done < <(ufw::get_menu_items)

    log_info_simple_tab "0. Выход"
    log::draw_lite_border
}

# @type:        Source
# @description: Запрашивает выбор пользователя и возвращает выбранный ID
# @params:      нет
# @stdin:       нет
# @stdout:      id\0 (0..2) - выбранный ID или 0 (выход)
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
ufw::get_user_choice() {
    local -a menu_items=()
    local max_id=0
    local id_text

    # Читаем все пункты в массив
    while IFS='|' read -r -d '' id_text || break; do
        menu_items+=("$id_text")
        local id="${id_text%%|*}"
        (( id > max_id )) && max_id=$id
    done < <(ufw::get_menu_items)

    local pattern="^[0-$max_id]$"

    local selection
    # Вернет код 2 при выборе 0
    selection=$(io::ask_value "Выберите действие" "" "$pattern" "0-$max_id" "0" | tr -d '\0') || return

    printf '%s\0' "$selection"
}

# @type:        Orchestrator
# @description: Выполняет выбранное действие на основе ID
# @params:      нет
# @stdin:       id\0 (0..2)
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от действия
ufw::execute_action() {
    local action_id
    read -r -d '' action_id || return 0

    case "$action_id" in
        1) ufw::toggle ;;
        2)
            if ufw::ping::is_configured; then
                ufw::ping::restore_ping
            else
                ufw::ping::disable_ping
            fi
            ;;
        *) log_error "Неверный ID действия: [$action_id]"; return 1 ;;
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

# @type:        Sink
# @description: Логирует состояние UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log_status() {
    if ufw::is_active; then
        log_info "UFW ВКЛ"
    else
        log_info "UFW ВЫКЛ"
    fi
}

# @type:        Orchestrator
# @description: Выполняет действия после установки порта: перезапуск сервисов и валидация
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - действия успешно выполнены
#               $? - ошибка в процессе
orchestrator::actions_after_ufw_change() {
    log::draw_lite_border
    log_actual_info "Актуальная информация после внесения изменений"
    ufw::log_status
    ufw::log_active_ufw_rules
}

# @type:        Filter
# @description: Применяет изменения UFW на основе выбранного действия
# @params:
#   action_id   ID выбранного действия
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка в процессе
ufw::apply_changes() {
    local action_id="$1"

    case "$action_id" in
        1) ufw::toggle ;;
        2)
            if ufw::ping::is_configured; then
                ufw::ping::restore_ping
            else
                ufw::ping::disable_ping
            fi
            ;;
        *) log_error "Неверный ID действия: [$action_id]"; return 1 ;;
    esac
}

# @type:        Filter
# @description: Запрашивает подтверждение успешной работы UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - подтверждение получено
#               2 - выход по запросу пользователя
ufw::confirm_success() {
    io::ask_value "Подтвердите работу UFW - введите confirmed" "" "^confirmed$" "confirmed" >/dev/null || return $?
}

# @type:        Filter
# @description: Проверяет, существует ли бэкап файл настроек PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - бэкап существует (PING отключен)
#               1 - бэкап не существует (PING не отключен)
ufw::ping::is_configured() {
    [[ -f "$UFW_BEFORE_RULES_BACKUP" ]]
}

# @type:        Filter
# @description: Создает бэкап файла before.rules
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - бэкап успешно создан
#               $? - код ошибки команды cp
ufw::ping::backup_file() {
    if ! cp "$UFW_BEFORE_RULES" "$UFW_BEFORE_RULES_BACKUP"; then
        log_error "Не удалось создать бэкап $UFW_BEFORE_RULES_BACKUP"
        return $?
    fi
}

# @type:        Transformer
# @description: Заменяет ACCEPT на DROP в ICMP правилах через awk
# @params:      нет
# @stdin:       содержимое before.rules
# @stdout:      преобразованный content (ACCEPT → DROP для ICMP)
# @exit_code:   0 - успешно
# @exit_code:   $? - код ошибки awk
ufw::ping::disable() {
    awk '
    BEGIN {
        IGNORECASE = 1
        in_input_section = 0
        in_forward_section = 0
    }

    /^#[[:space:]]*ok[[:space:]]+icmp[[:space:]]+codes?[[:space:]]+for[[:space:]]+INPUT$/ {
        in_input_section = 1
        print
        next
    }

    /^#[[:space:]]*ok[[:space:]]+icmp[[:space:]]+code[[:space:]]+for[[:space:]]+FORWARD$/ {
        in_forward_section = 1
        print
        next
    }

    /^#/ && !(in_input_section || in_forward_section) {
        in_input_section = 0
        in_forward_section = 0
        print
        next
    }

    (in_input_section || in_forward_section) && /^-[[:space:]]*A[[:space:]]+ufw-before-(input|forward)[[:space:]]+-p[[:space:]]+icmp/ {
        gsub(/[[:space:]]+-j[[:space:]]+ACCEPT/, " -j DROP")
        print
        next
    }

    { print }
    '
}

# @type:        Filter
# @description: Восстанавливает файл before.rules из бэкапа и удаляет бэкап
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно восстановлено
#               $? - код ошибки cp или rm
ufw::ping::restore() {
    if ! cp "$UFW_BEFORE_RULES_BACKUP" "$UFW_BEFORE_RULES"; then
        log_error "Не удалось восстановить $UFW_BEFORE_RULES из бэкапа"
        return $?
    fi

    if ! rm "$UFW_BEFORE_RULES_BACKUP"; then
        log_error "Не удалось удалить бэкап файл $UFW_BEFORE_RULES_BACKUP"
        return $?
    fi
}

# @type:        Sink
# @description: Выполняет ufw reload для применения изменений
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки ufw reload
ufw::ping::reload() {
    if ! ufw reload >/dev/null; then
        log_error "Не удалось выполнить ufw reload"
        return $?
    fi
}

# @type:        Orchestrator
# @description: Отключает пинг через UFW (бэкап + трансформация + reload)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки операции
ufw::ping::disable_ping() {
    local tmp_file="${UFW_BEFORE_RULES}.tmp"

    ufw::ping::backup_file
    ufw::ping::disable < "$UFW_BEFORE_RULES" > "$tmp_file" && mv "$tmp_file" "$UFW_BEFORE_RULES" || { log_error "Не удалось применить изменения"; [[ -f "$tmp_file" ]] && rm "$tmp_file"; return $?; }
    [[ -f "$tmp_file" ]] && rm "$tmp_file"
    ufw::ping::reload
}

# @type:        Orchestrator
# @description: Восстанавливает настройки PING по умолчанию (восстановление + reload)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки операции
ufw::ping::restore_ping() {
    ufw::ping::restore
    ufw::ping::reload
}
