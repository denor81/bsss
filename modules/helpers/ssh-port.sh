# === SOURCE ===

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
        new_port=$(io::ask_value "$(_ "ssh.ui.get_new_port.prompt")" "$suggested_port" "$port_pattern" "$(_ "ssh.ui.get_new_port.hint_range" "$suggested_port")" "0" | tr -d '\0') || return

         # Проверка на занятость порта
        ssh::port::is_port_free "$new_port" && { printf '%s\0' "$new_port"; break; }
        log_error "$(_ "ssh.error_port_busy" "$new_port")"
    done
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

# === FILTER ===

# @type:        Filter
# @description: Удаляет все правила BSSS и передает порт дальше
# @params:      нет
# @stdin:       port\0 (опционально)
# @stdout:      port\0 (опционально)
# @exit_code:   0 - успешно
ssh::rule::reset_and_pass() {
    local port=""

    # || true нужен что бы гасить код 1 при false кода [[ ! -t 0 ]]
    [[ ! -t 0 ]] && read -r -d '' port || true
    
    ssh::rule::delete_all_bsss

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
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
        log_info "$(_ "ssh.success_rule_created" "$path" "$port")"
    else
        log_error "$(_ "ssh.error_rule_creation_failed" "$path")"
        return 1
    fi
}

# === VALIDATOR ===

# @type:        Validator
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

# === SINK ===

# @type:        Sink
# @description: Основной функционал установки/изменения SSH порта
# @params:      нет
# @stdin:       port\0
# @stdout:      нет
# @exit_code:   0 - порт успешно установлен
#               $? - ошибка в процессе
ssh::port::install_new() {
    local port
    read -r -d '' port

    printf '%s\0' "$port" | ssh::config::create_bsss_file
    printf '%s\0' "$port" | ufw::rule::add_bsss
}

# @type:        Sink
# @description: Удаляет все правила BSSS SSH
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::rule::delete_all_bsss() {
    # || true нужен что бы гасить код 1 при отсутствии файлов
    sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | sys::file::delete || true
}

# @type:        Sink
# @description: Выполняет действия после установки порта: перезапуск сервисов и валидация
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - действия успешно выполнены
#               $? - ошибка в процессе
ssh::orchestrator::log_statuses() {
    ssh::log::active_ports_from_ss
    ssh::log::bsss_configs
    ufw::log::rules
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
            log_info "$(_ "ssh.info_rules_found")"
            found=$((found + 1))
        fi

        log_info_simple_tab "$(_ "no_translate" "$grep_result")"

    done < <(grep -EiHs '^\s*port\b' "${SSH_CONFIGD_DIR}/"$BSSS_SSH_CONFIG_FILE_MASK || true)

    if (( found == 0 )); then
        log_info "$(_ "ssh.info_no_rules" "$SSH_CONFIG_FILE")"
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
            log_info "$(_ "ssh.warning_external_rules_found")"
            found=$((found + 1))
        fi

        log_info_simple_tab "$(_ "no_translate" "$grep_result")"

    done < <(grep -EiHs --exclude="${SSH_CONFIGD_DIR}/"$BSSS_SSH_CONFIG_FILE_MASK '^\s*port\b' "${SSH_CONFIGD_DIR}/"$SSH_CONFIG_FILE_MASK "$SSH_CONFIG_FILE" || true)

    if (( found == 0 )); then
        log_info "$(_ "ssh.warning_no_external_rules" "$SSH_CONFIG_FILE")"
    fi
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
    log_attention "$(_ "ssh.guard.dont_close")"
    log_attention "$(_ "ssh.guard.test_new" "$port")"
}
