# @type:        Validator
# @description: Проверяет, есть ли правила UFW BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - есть хотя бы одно правило BSSS
#               1 - нет правил BSSS
ufw::rule::has_any_bsss() {
    ufw::rule::get_all_bsss | read -r -d '' _
}

# === SOURCE ===

# @type:        Source
# @description: Генерирует список доступных пунктов меню на основе текущего состояния
# @params:      нет
# @stdin:       нет
# @stdout:      id|text\0 (0..N)
# @exit_code:   0 - успешно
ufw::menu::get_items() {
    ufw::status::is_active && printf '%s|%s\0' "1" "$(_ "ufw.menu.item_disable")" || printf '%s|%s\0' "1" "$(_ "ufw.menu.item_enable")"
    ufw::ping::is_configured && printf '%s|%s\0' "2" "$(_ "ufw.menu.item_ping_enable")" || printf '%s|%s\0' "2" "$(_ "ufw.menu.item_ping_disable")"
    printf '%s|%s\0' "0" "$(_ "ufw.menu.item_exit")"
}

# @type:        Source
# @description: Считает количество пунктов меню (Корректно работает до 9 пунктов)
# @params:      нет
# @stdin:       нет
# @stdout:      number - количество пунктов меню
# @exit_code:   0 - успешно
ufw::menu::count_items() {
    ufw::menu::get_items | grep -cz '^'
}

# === FILTER ===

# @type:        Filter
# @description: Запрашивает выбор пользователя и возвращает выбранный ID
# @params:      нет
# @stdin:       нет
# @stdout:      id\0 (0..2) - выбранный ID или 0 (выход)
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
ufw::menu::get_user_choice() {
    local qty_items=$(($(ufw::menu::count_items) - 1)) # вычитаем один элемент - 0 пункт меню, что бы корректно отображать маску
    local pattern="^[0-$qty_items]$"
    local hint="0-$qty_items"

    io::ask_value "$(_ "ufw.menu.ask_select")" "" "$pattern" "$hint" "0" # Вернет 0 или 2 при отказе (или 130 при ctrl+c)
}

# === VALIDATOR ===

# === SINK ===

# @type:        Sink
# @description: Отображает пункты меню пользователю (вывод только в stderr)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::menu::display() {
    local id
    local text

    ufw::log::status
    ufw::log::rules
    ufw::log::ping_status

    log_info "$(_ "common.menu_header")"

    while IFS='|' read -r -d '' id text || break; do
        log_info_simple_tab "$(_ "no_translate" "$id. $text")"
    done < <(ufw::menu::get_items)
}

# @type:        Sink
# @description: Логирует состояние UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log::status() {
    ufw::status::is_active && \
    log_info "$(_ "ufw.status.enabled")" || \
    log_info "$(_ "ufw.status.disabled")"
}

# @type:        Sink
# @description: Логирует состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log::ping_status() {
    ufw::ping::is_configured && \
    log_info "$(_ "ufw.status.ping_blocked")" || \
    log_info "$(_ "ufw.status.ping_allowed")"
}

# @type:        Sink
# @description: Создает бэкап файла before.rules
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - бэкап успешно создан
#               $? - код ошибки команды cp
ufw::ping::backup_file() {
    local res
    if res=$(cp -pv "$UFW_BEFORE_RULES" "$UFW_BEFORE_RULES_BACKUP" 2>&1); then
        log_info "$(_ "ufw.success.backup_created" "$res")"
    else
        local rc=$?
        log_error "$(_ "ufw.error.backup_failed" "$UFW_BEFORE_RULES_BACKUP" "$res")"
        return "$rc"
    fi
}

# @type:        Sink
# @description: Выполняет ufw reload для применения изменений
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки ufw reload
ufw::status::reload() {
    if ufw reload >/dev/null; then
        log_info "$(_ "ufw.success.reloaded")"
    else
        local rc=$?
        log_error "$(_ "ufw.error.reload_failed" "$rc")"
        return "$rc"
    fi
}
