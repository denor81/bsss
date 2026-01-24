#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

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
    suggested_port=$(ssh::port::generate_free_random_port) || return

    local new_port
    while true; do
        new_port=$(io::ask_value "Введите новый SSH порт" "$suggested_port" "$port_pattern" "1-65535, Enter для $suggested_port" "0" | tr -d '\0') || return
        ssh::port::is_port_busy "$new_port" || { printf '%s\0' "$new_port"; break; }
        log_error "SSH порт $new_port уже занят другим сервисом."
    done
}

# @type:        Orchestrator
# @description: Выводит все BSSS конфигурации SSH с портами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::config::log_bsss_with_ports() {
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

# @type:        Orchestrator
# @description: Выводит все сторонние конфигурации SSH с портами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::config::log_other_with_ports() {
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
    sys::restart_services

    log::draw_lite_border
    log_actual_info "Актуальная информация после внесения изменений"
    ssh::log_active_ports_from_ss
    ssh::config::log_bsss_with_ports
    ufw::rule::log_active
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
    # || true нужен потому что sys::get_paths_by_mask может возвращать пустоту и read зависает
    sys::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | sys::delete_paths || true
}

# @type:        Orchestrator
# @description: Перезапускает SSH сервис после проверки конфигурации
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - сервис успешно перезапущен
#               1 - ошибка конфигурации
sys::restart_services() {
    if sshd -t; then
        systemctl daemon-reload && log_info "Конфигурация перезагружена [systemctl daemon-reload]"
        systemctl restart ssh && log_info "SSH сервис перезагружен [systemctl restart ssh]"
    else
        log_error "Ошибка конфигурации ssh [sshd -t]"
        return 1
    fi
}

# @type:        Filter
# @description: Проверяет, занят ли указанный порт
# @params:
#   port        Номер порта для проверки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - порт свободен
#               1 - порт занят
ssh::port::is_port_busy() {
    ss -ltn | grep -qE ":$1([[:space:]]|$)"
}

# @type:        Source
# @description: Генерирует случайный свободный порт в диапазоне 10000-65535
# @params:      нет
# @stdin:       нет
# @stdout:      port
# @exit_code:   0 - порт успешно сгенерирован
#               $? - ошибка
ssh::port::generate_free_random_port() {
    while IFS= read -r port || break; do
        if ! ssh::port::is_port_busy "$port"; then
            printf '%s\n' "$port"
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

# @type:        Sink
# @description: Отображает пункты меню пользователю
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::ui::display_menu() {
    log::draw_lite_border
    log_info "Доступные действия:"
    log_info_simple_tab "0. Выход"
}

# @type:        Filter
# @description: Применяет изменения SSH порта (сброс старых правил и установка новых)
# @params:
#   port        Номер порта для установки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка в процессе
ssh::rule::apply_changes() {
    local port="$1"
    printf '%s\0' "$port" | ssh::rule::reset_and_pass | ufw::rule::reset_and_pass | ssh::port::install_new
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
        if ssh::get_ports_from_ss | grep -qzxF "$port"; then
            log_info "SSH порт $port успешно поднят"
            return 0
        fi

        sleep "$interval"
        elapsed=$((elapsed + 1))
        attempts=$((attempts + 1))
    done

    log_error "ПОРТ $port НЕ ПОДНЯЛСЯ [$attempts попыток в течение ${timeout} сек]"
    return 1
}
