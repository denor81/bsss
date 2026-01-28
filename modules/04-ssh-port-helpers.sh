# @type:        Sink
# @description: Отображает меню сценария с существующими конфигами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::menu::display_exists_scenario() {
    ssh::log::bsss_configs

    log_info "Доступные действия:"
    log_info_simple_tab "1. Сброс (удаление правила ${UTIL_NAME^^})"
    log_info_simple_tab "2. Переустановка (замена на новый порт)"
    log_info_simple_tab "0. Выход"
}

# @type:        Sink
# @description: Отображает меню сценария установки
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::menu::display_install_ui() {
    log::draw_lite_border
    log_info "Доступные действия:"
    log_info_simple_tab "0. Выход"
}

# @type:        Filter
# @description: Основной функционал установки/изменения SSH порта
# @params:      нет
# @stdin:       port\0
# @stdout:      port\0
# @exit_code:   0 - порт успешно установлен
#               $? - ошибка в процессе
ssh::port::install_new() {
    local new_port
    read -r -d '' new_port

    printf '%s\0' "$new_port" | ssh::config::create_bsss_file
    printf '%s\0' "$new_port" | ufw::rule::add_bsss
}

# @type:        Source
# @description: Запрашивает у пользователя новый SSH порт
# @params:      нет
# @stdin:       нет
# @stdout:      port\0
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - ошибка
ssh::ui::get_new_port() {
    local port_pattern="^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"

    local suggested_port
    read -r -d '' suggested_port < <(ssh::port::generate_free_random_port)

    local new_port
    while true; do
        new_port=$(io::ask_value "Введите новый SSH порт" "$suggested_port" "$port_pattern" "1-65535, Enter для $suggested_port" "0" | tr -d '\0') || return

         # Проверка на занятость порта
        ssh::port::is_port_free "$new_port" && { printf '%s\0' "$new_port"; break; }
        log_error "SSH порт $new_port уже занят другим сервисом."
    done
}

# @type:        Sink
# @description: Логирует все BSSS конфигурации SSH с портами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::log::bsss_configs() {
    local grep_result
    local found=0

    while IFS= read -r grep_result || break; do

        if (( found == 0 )); then
            log_info "Есть правила ${UTIL_NAME^^} для SSH:"
            found=$((found + 1))
        fi

        log_info_simple_tab "$grep_result"

    done < <(grep -EiHs '^\s*port\b' "${SSH_CONFIGD_DIR}/"$BSSS_SSH_CONFIG_FILE_MASK || true)

    if (( found == 0 )); then
        log_info "Нет правил ${UTIL_NAME^^} для SSH [$SSH_CONFIG_FILE]"
    fi
}

# @type:        Sink
# @description: Логирует все сторонние конфигурации SSH с портами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::log::other_configs() {
    local grep_result
    local found=0

    while IFS= read -r grep_result || break; do

        if (( found == 0 )); then
            log_info "Есть сторонние правила SSH:"
            found=$((found + 1))
        fi

        log_info_simple_tab "$grep_result"

    done < <(grep -EiHs --exclude="${SSH_CONFIGD_DIR}/"$BSSS_SSH_CONFIG_FILE_MASK '^\s*port\b' "${SSH_CONFIGD_DIR}/"$SSH_CONFIG_FILE_MASK "$SSH_CONFIG_FILE" || true)

    if (( found == 0 )); then
        log_info "Нет сторонних правил SSH [$SSH_CONFIG_FILE]"
    fi
}

# @type:        Orchestrator
# @description: Выполняет действия после установки порта: перезапуск сервисов и валидация
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - действия успешно выполнены
#               $? - ошибка в процессе
ssh::orchestrator::actions_after_port_change() {
    sys::service::restart

    log::draw_lite_border
    log_actual_info
    ssh::port::log_active_from_ss
    ssh::log::bsss_configs
    ufw::log::rules
}

# @type:        Filter
# @description: Удаляет все правила BSSS и передает порт дальше
# @params:      нет
# @stdin:       port\0 (опционально)
# @stdout:      port\0 (опционально)
# @exit_code:   0 - успешно
ssh::rule::reset_and_pass() {
    local port=""

    # || true нужен что бы гасить код 1 при false кода [[ ! -t 0 ]]
    [[ ! -t 0 ]] && IFS= read -r -d '' port || true
    
    ssh::rule::delete_all_bsss

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}

# @type:        Orchestrator
# @description: Удаляет все правила BSSS SSH
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::rule::delete_all_bsss() {
    sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | sys::file::delete
}

# @type:        Source
# @description: Проверяет, что указанный порт свободен
# @params:      
#   port        Номер порта для проверки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - порт свободен
#               1 - порт занят
ssh::port::is_port_free() {
    ! ss -ltn | grep -qE ":$1([[:space:]]|$)"
}

# @type:        Source
# @description: Генерирует случайный свободный порт в диапазоне 10000-65535
# @params:      нет
# @stdin:       нет
# @stdout:      port\0
# @exit_code:   0 - порт успешно сгенерирован
#               $? - ошибка
ssh::port::generate_free_random_port() {
    while IFS= read -r port || break; do
        if ssh::port::is_port_free "$port"; then
            printf '%s\0' "$port"
            return
        fi
    done < <(shuf -i 10000-65535)
}

# @type:        Filter
# @description: Создает новый конфигурационный файл SSH с указанным портом
# @params:      нет
# @stdin:       port\0
# @stdout:      нет
# @exit_code:   0 - файл успешно создан
#               1 - ошибка создания
ssh::config::create_bsss_file() {
    local path="${SSH_CONFIGD_DIR}/$BSSS_SSH_CONFIG_FILE_NAME"
    local port
    read -r -d '' port
    
    # Создаем файл с настройкой порта
    if cat > "$path" << EOF
# $BSSS_MARKER_COMMENT
# SSH port configuration
Port $port
EOF
    then
        log_info "Создано правило ${UTIL_NAME^^} для SSH: [$path:$port]"
    else
        log_error "Не удалось создать правило SSH: $path"
        return 1
    fi
}

# @type:        Filter
# @description: Блокирующая проверка поднятия SSH порта после изменения
#               Проверяет порт в цикле с интервалом 0.5 секунды
#               При успешном обнаружении возвращает 0
#               При истечении таймаута возвращает 1
# @params:
#   port        Номер порта для проверки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - порт успешно поднят
#               1 - порт не поднялся в течение таймаута
ssh::port::wait_for_up() {
    local port="$1"
    local timeout="${SSH_PORT_CHECK_TIMEOUT:-5}"
    local elapsed=0
    local interval=0.5
    local attempts=0

    log_info "Ожидание поднятия SSH порта $port (таймаут: ${timeout} сек)..."

    while (( elapsed < timeout )); do
        # Проверяем, есть ли порт в списке активных
        if ssh::port::get_from_ss | grep -qzxF "$port"; then
            log_info "SSH порт $port успешно поднят после $attempts попыток в течение $elapsed сек"
            return
        fi

        sleep "$interval"
        elapsed=$((elapsed + 1))
        attempts=$((attempts + 1))
    done

    log_error "ПОРТ $port НЕ ПОДНЯЛСЯ [$attempts попыток в течение $timeout сек]"
    return 1
}

# @type:        Orchestrator
# @description: Обработчик сценария с существующими конфигами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ssh::orchestrator::config_exists_handler() {
    ssh::menu::display_exists_scenario
    local choice
    read -r -d '' choice < <(io::ask_value "Выберите" "" "^[012]$" "0-2" "0")

    case "$choice" in
        1) ssh::toggle::reset_port ;;
        2) ssh::toggle::install_port ;;
        *) return 2 ;;
    esac
}

# @type:        Orchestrator
# @description: Обработчик сценария отсутствия конфигов
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ssh::orchestrator::config_not_exists_handler() {
    ssh::toggle::install_port
}

# @type:        Orchestrator
# @description: Устанавливает новый SSH порт с механизмом rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ssh::toggle::install_port() {
    local port

    ssh::menu::display_install_ui

    port=$(ssh::ui::get_new_port | tr -d '\0') || return

    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ssh")

    ssh::log::guard_instructions "$port"

    printf '%s\0' "$port" | ssh::rule::reset_and_pass | ufw::rule::reset_and_pass | ssh::port::install_new

    ssh::orchestrator::actions_after_port_change

    if ! ssh::port::wait_for_up "$port"; then
        kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
        wait "$WATCHDOG_PID" 2>/dev/null || true
        while true; do sleep 1; done
    fi

    if io::ask_value "Подтвердите подключение - введите connected" "" "^connected$" "connected" >/dev/null; then
        rollback::orchestrator::watchdog_stop "$WATCHDOG_PID"
        log_info "Изменения зафиксированы, Rollback отключен"
    fi
}

# @type:        Orchestrator
# @description: Сбрасывает SSH порт (удаляет все BSSS правила)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
ssh::toggle::reset_port() {
    ssh::rule::reset_and_pass | ufw::rule::reset_and_pass
    ssh::orchestrator::actions_after_port_change
}

# @type:        Sink
# @description: Отображает инструкции guard для пользователя
# @params:
#   port        Номер порта
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::log::guard_instructions() {
    local port="$1"
    log::draw_lite_border
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "ОТКРОЙТЕ НОВОЕ ОКНО и проверьте связь через порт $port"
}

# @type:        Orchestrator
# @description: Перезапускает SSH сервис после проверки конфигурации
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - сервис успешно перезапущен
#               1 - ошибка конфигурации
sys::service::restart() {
    if sshd -t; then
        systemctl daemon-reload && log_info "Конфигурация перезагружена [systemctl daemon-reload]"
        systemctl restart ssh && log_info "SSH сервис перезагружен [systemctl restart ssh]"
    else
        log_error "Ошибка конфигурации ssh [sshd -t]"
        return 1
    fi
}
