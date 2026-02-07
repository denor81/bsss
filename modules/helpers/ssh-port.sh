# @type:        Sink
# @description: Отображает меню сценария с существующими конфигами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::menu::display_exists_scenario() {
    ssh::log::active_ports_from_ss
    ssh::log::bsss_configs

    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "$(_ "ssh.menu.item_reset" "1" "${UTIL_NAME^^}")"
    log_info_simple_tab "$(_ "ssh.menu.item_reinstall" "2")"
    log_info_simple_tab "$(_ "common.exit" "0")"
}

# @type:        Orchestrator
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

# @type:        Orchestrator
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

# @type:        Orchestrator
# @description: Удаляет все правила BSSS SSH
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::rule::delete_all_bsss() {
    # || true нужен что бы гасить код 1 при отсутствии файлов
    sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | sys::file::delete || true
}

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
        log_info "$(_ "ssh.success_rule_created" "$path" "$port")"
    else
        log_error "$(_ "ssh.error_rule_creation_failed" "$path")"
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
    local attempts=1

    log_info "$(_ "ssh.socket.wait_for_ssh_up.info" "$port" "$timeout")"

    while (( elapsed < timeout )); do
        # Проверяем, есть ли порт в списке активных
        if ssh::port::get_from_ss | grep -qzxF "$port"; then
            log_info "$(_ "ssh.success_port_up" "$port" "$attempts" "$elapsed")"
            return
        fi

        sleep "$interval"
        elapsed=$((elapsed + 1))
        attempts=$((attempts + 1))
    done

    log_error "$(_ "ssh.error_port_not_up" "$port" "$attempts" "$timeout")"
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
    choice=$(io::ask_value "$(_ "ssh.ui.get_action_choice.ask_select")" "" "^[012]$" "0-2" "0" | tr -d '\0') || return

    case "$choice" in
        1) ssh::reset::port ;;
        2) ssh::install::port ;;
        *) log_warn "$(_ "ssh.error_invalid_choice")" ;;
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
    ssh::install::port
}

# @type:        Orchestrator
# @description: Инициирует немедленный откат через SIGUSR2 и ожидает завершения watchdog
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - откат выполнен, процесс заблокирован
ssh::orchestrator::trigger_immediate_rollback() {
    kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
    while true; do sleep 1; done
}

# @type:        Orchestrator
# @description: Устанавливает новый SSH порт с механизмом rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ssh::install::port() {
    local port

    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "$(_ "common.info_menu_item_format" "0" "$(_ "common.exit")")"

    port=$(ssh::ui::get_new_port | tr -d '\0') || return

    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ssh")

    ssh::log::guard_instructions "$port"

    printf '%s\0' "$port" | ssh::rule::reset_and_pass | ufw::rule::reset_and_pass | ssh::port::install_new

    sys::service::restart
    log_actual_info
    ssh::orchestrator::log_statuses

    if ! ssh::port::wait_for_up "$port"; then
        ssh::orchestrator::trigger_immediate_rollback
    fi

    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "$(_ "common.info_menu_item_format" "0" "$(_ "common.exit")")"

    if io::ask_value "$(_ "ssh.install.confirm_connection")" "" "^connected$" "connected" "0" >/dev/null; then
        rollback::orchestrator::watchdog_stop "$WATCHDOG_PID"
        log_info "$(_ "ssh.success_changes_committed")"
    else
        ssh::orchestrator::trigger_immediate_rollback
    fi
}

# @type:        Orchestrator
# @description: Сбрасывает SSH порт (удаляет все BSSS правила)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
ssh::reset::port() {
    ssh::rule::reset_and_pass | ufw::rule::reset_and_pass

    ufw::status::force_disable # Для гарантированного доступа

    sys::service::restart
    log_actual_info
    ssh::orchestrator::log_statuses
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

# @type:        Orchestrator
# @description: Перезапускает SSH сервис после проверки конфигурации
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - сервис успешно перезапущен
#               1 - ошибка конфигурации
sys::service::restart() {
    if sshd -t; then
        systemctl daemon-reload && log_info "$(_ "ssh.service.daemon_reloaded")"
        systemctl restart ssh.service && log_info "$(_ "ssh.service.restarted")"
    else
        log_error "$(_ "ssh.error_config_sshd")"
        return 1
    fi
}
