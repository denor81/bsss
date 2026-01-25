#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# @type:        Source
# @description: Генерирует список доступных пунктов меню на основе текущего состояния
# @params:      нет
# @stdin:       нет
# @stdout:      id|text\0 (0..N)
# @exit_code:   0 - успешно
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

# @type:        Source
# @description: Запрашивает выбор пользователя и возвращает выбранный ID
# @params:      нет
# @stdin:       нет
# @stdout:      id\0 (0..2) - выбранный ID или 0 (выход)
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
ufw::menu::get_user_choice() {
    local max_id=0
    max_id=$(ufw::menu::get_items | grep -cz '^')

    local pattern="^[0-$max_id]$"

    # Вернет код 2 при выборе 0
    local selection
    selection=$(io::ask_value "Выберите действие" "" "$pattern" "0-$max_id" "0" | tr -d '\0') || return

    printf '%s\0' "$selection"
}

# @type:        Orchestrator
# @description: Применяет изменения UFW на основе выбранного действия
# @params:
#   action_id   ID выбранного действия
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка в процессе
ufw::orchestrator::apply_changes() {
    local action_id="$1"

    case "$action_id" in
        1) ufw::ui::status_toggle ;;
        2) ufw::ui::ping_toggle ;;
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
ufw::ui::status_toggle() {
    if ufw::rule::is_active; then
        ufw::rule::force_disable
    else
        ufw::rule::force_enable
    fi
}

# @type:        Filter
# @description: Активирует UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::rule::force_enable() {
    local watchdog_pid

    # Rollback только при включении UFW
    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ufw")
    rollback::orchestrator::guard_ui_instructions

    if ufw --force enable >/dev/null 2>&1; then
        log_info "UFW: Активирован [ufw --force enable]"
    else
        log_error "Ошибка при активации [ufw --force enable]"
    fi

    ufw::orchestrator::actions_after_ufw_toggle

    if io::ask_value "Подтвердите возможность подключения - введите connected" "" "^connected$" "connected" >/dev/null; then
        rollback::orchestrator::watchdog_stop
    fi
}

# @type:        Sink
# @description: Переключает состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
ufw::ui::ping_toggle() {
    if ufw::ping::is_configured; then
        ufw::ping::restore_ping
    else
        ufw::ping::disable_ping
    fi
}

# @type:        Sink
# @description: Логирует состояние UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log::status() {
    if ufw::rule::is_active; then
        log_info "UFW включен"
    else
        log_info "UFW отключен"
    fi
}

# @type:        Sink
# @description: Логирует состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log::ping_status() {
    if ufw::ping::is_configured; then
        log_info "UFW ping отключен [DROP] [Состояние: модифицировано]"
    else
        log_info "UFW ping работает [ACCEPT] [Состояние: по умолчанию]"
    fi
}

# @type:        Orchestrator
# @description: Выполняет действия после вкл/выкл UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - действия успешно выполнены
#               $? - ошибка в процессе
ufw::orchestrator::actions_after_ufw_toggle() {
    log::draw_lite_border
    log_actual_info "Актуальная информация после внесения изменений"
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
ufw::ping::reload() {
    if ufw reload >/dev/null; then
        log_info "UFW перезагружен [ufw reload]"
    else
        local rc=$?
        log_error "Не удалось выполнить [ufw reload] [Code: $rc]"
        return "$rc"
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
    ufw::ping::backup_file || return 1
    ufw::ping::disable_in_rules
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
