# @type:        Source
# @description: Генерирует список доступных пунктов меню на основе текущего состояния
# @params:      нет
# @stdin:       нет
# @stdout:      id|text\0 (0..N)
# @exit_code:   0 - успешно
ufw::menu::get_items() {
    ufw::status::is_active && printf '%s|%s\0' "1" "Выключить UFW" || printf '%s|%s\0' "1" "Включить UFW"
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

    ufw::orchestrator::ufw_statuses

    log_info "Доступные действия:"

    while IFS='|' read -r -d '' id text || break; do
        log_info_simple_tab "$id. $text"
    done < <(ufw::menu::get_items)

    log::draw_lite_border
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

    io::ask_value "Выберите действие" "" "$pattern" "$hint" "0" # Вернет 0 или 2 при отказе (или 130 при ctrl+c)
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
        *) log_error "Неверный ID действия: [$menu_id]"; return 1 ;;
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
        rollback::orchestrator::immediate
        log_error "Ошибка при активации [ufw --force enable]"
        return 1
    fi

    log_info "UFW: Активирован [ufw --force enable]"
    log_actual_info
    ufw::orchestrator::ufw_statuses

    if io::ask_value "Подтвердите возможность подключения - введите connected" "" "^connected$" "connected" "cancel" >/dev/null; then
        rollback::orchestrator::watchdog_stop
    fi
}

# @type:        Sink
# @description: Отображает инструкции пользователю для проверки подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
log::rollback::instructions() {
    log::draw_lite_border
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "Проверьте доступ к серверу после включения UFW"
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
    log_info "UFW включен" || \
    log_info "UFW отключен"
}

# @type:        Sink
# @description: Логирует состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log::ping_status() {
    ufw::ping::is_configured && \
    log_info "UFW ping запрещен [DROP] [Состояние: модифицировано]" || \
    log_info "UFW ping разрешен [ACCEPT] [Состояние: по умолчанию]"
}

# @type:        Orchestrator
# @description: Отображает статусы UFW: общее состояние, правила, состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - Всегда успешно
ufw::orchestrator::ufw_statuses() {
    log::draw_lite_border
    # log_actual_info
    ufw::log::status
    ufw::log::rules
    ufw::log::ping_status
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
    local res
    if res=$(cp -pv "$UFW_BEFORE_RULES" "$UFW_BEFORE_RULES_BACKUP" 2>&1); then
        log_info "Создан бэкап: [$res]"
    else
        local rc=$?
        log_error "Не удалось создать бэкап $UFW_BEFORE_RULES_BACKUP [$res]"
        return "$rc"
    fi
}

# @type:        Transformer
# @description: Заменяет ACCEPT на DROP в ICMP правилах через
# @params:      нет
# @stdin:       содержимое before.rules
# @stdout:      преобразованный content (ACCEPT → DROP для ICMP)
# @exit_code:   0 - успешно
# @exit_code:   $? - код ошибки команды sed
ufw::ping::disable_in_rules() {
    if sed -i '/-p icmp/s/ACCEPT/DROP/g' "$UFW_BEFORE_RULES"; then
        log_info "Отредактирован: [$UFW_BEFORE_RULES]"
        log_info "ICMP правила изменены на DROP"
    else
        log_error "Ошибка при редактировании: [$UFW_BEFORE_RULES]"
        return 1
    fi
}

# @type:        Filter
# @description: Восстанавливает файл before.rules из бэкапа и удаляет бэкап
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно восстановлено
#               $? - код ошибки cp или rm
ufw::ping::restore() {
    if res=$(cp -pv "$UFW_BEFORE_RULES_BACKUP" "$UFW_BEFORE_RULES" 2>&1); then
        log_info "Восстановлен файл before.rules: [$res]"
    else
        local rc=$?
        log_error "Не удалось восстановить $UFW_BEFORE_RULES из бэкапа [$res]"
        return "$rc"
    fi

    printf '%s\0' "$UFW_BEFORE_RULES_BACKUP" | sys::file::delete
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
        log_info "UFW перезагружен [ufw reload]"
    else
        local rc=$?
        log_error "Не удалось выполнить [ufw reload] [Code: $rc]"
        return "$rc"
    fi
}
