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

# @type:        Orchestrator
# @description: Проверяет требования для запуска UFW модуля
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - требования выполнены
#               4 - требования не выполнены
ufw::rule::check_requirements() {
    if ufw::rule::has_any_bsss; then
        return
    fi

    if ufw::status::is_active; then
        log_info "$(_ "ufw.info.no_rules_but_active")"
        return
    else
        log_warn "$(_ "ufw.warning.continue_without_rules")"
        log_info "$(_ "ufw.warning.add_ssh_first")"
        return 4
    fi
}

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

# @type:        Sink
# @description: Отображает пункты меню пользователю (вывод только в stderr)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::menu::display() {
    local id
    local text

    ufw::orchestrator::log_statuses

    log_info "$(_ "common.menu_header")"

    while IFS='|' read -r -d '' id text || break; do
        log_info_simple_tab "$(_ "no_translate" "$id. $text")"
    done < <(ufw::menu::get_items)
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

# @type:        Source
# @description: Запрашивает выбор пользователя и возвращает выбранный ID
# @params:      нет
# @stdin:       нет
# @stdout:      id\0 (0..2) - выбранный ID или 0 (выход)
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
ufw::menu::get_user_choice() {
    local qty_items=$(ufw::menu::count_items)
    local pattern="^[0-$qty_items]$"
    local hint="0-$qty_items"

    io::ask_value "$(_ "ufw.menu.ask_select")" "" "$pattern" "$hint" "0" # Вернет 0 или 2 при отказе (или 130 при ctrl+c)
}

# @type:        Orchestrator
# @description: Применяет изменения UFW на основе выбранного действия
# @params:
#   menu_id     ID выбранного действия
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка в процессе
ufw::orchestrator::dispatch_logic() {
    local menu_id="$1"

    case "$menu_id" in
        1) ufw::toggle::status ;;
        2) ufw::toggle::ping ;;
        *) log_error "$(_ "ufw.error.invalid_menu_id" "$menu_id")"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Переключает состояние UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
ufw::toggle::status() {
    if ufw::status::is_active; then
        ufw::status::force_disable
    else
        ufw::status::force_enable
    fi
}

# @type:        Orchestrator
# @description: Активирует UFW с watchdog и подтверждением подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отменено пользователем (подтверждение не получено)
#               1 - ошибка активации UFW
ufw::status::force_enable() {
    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ufw")
    log::rollback::instructions

    if ! ufw --force enable >/dev/null 2>&1; then
        rollback::orchestrator::immediate_usr2
        log_error "$(_ "ufw.error.enable_failed")"
        return 1
    fi

    log_info "$(_ "ufw.success.enabled")"
    log_actual_info
    ufw::orchestrator::log_statuses

    if io::ask_value "$(_ "ufw.install.confirm_connection")" "" "^connected$" "connected" "0" >/dev/null; then
        rollback::orchestrator::watchdog_stop
    else
        rollback::orchestrator::immediate_usr2
    fi
}

# @type:        Sink
# @description: Отображает инструкции пользователю для проверки подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
log::rollback::instructions() {
    log_attention "$(_ "ufw.rollback.warning_title")"
    log_attention "$(_ "ufw.rollback.test_access")"
}

# @type:        Orchestrator
# @description: Переключает состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
ufw::toggle::ping() {
    if ufw::ping::is_configured; then
        ufw::ping::restore
    else
        ufw::orchestrator::disable_ping
    fi
    ufw::status::reload
}

# @type:        Orchestrator
# @description: Отключает пинг через UFW (бэкап + трансформация + reload)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки операции
ufw::orchestrator::disable_ping() {
    ufw::ping::backup_file
    ufw::ping::disable_in_rules
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

# @type:        Orchestrator
# @description: Отображает статусы UFW: общее состояние, правила, состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - Всегда успешно
ufw::orchestrator::log_statuses() {
    ufw::log::status
    ufw::log::rules
    ufw::log::ping_status
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

# @type:        Orchestrator
# @description: Заменяет ACCEPT на DROP в ICMP правилах файла before.rules
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки команды sed
ufw::ping::disable_in_rules() {
    if sed -i '/-p icmp/s/ACCEPT/DROP/g' "$UFW_BEFORE_RULES"; then
        log_info "$(_ "ufw.success.before_rules_edited" "$UFW_BEFORE_RULES")"
        log_info "$(_ "ufw.success.icmp_changed")"
    else
        log_error "$(_ "ufw.error.edit_failed" "$UFW_BEFORE_RULES")"
        return 1
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
