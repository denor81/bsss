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
ssh::install_new_port() {
    local new_port
    read -r -d '' new_port

    printf '%s\0' "$new_port" | ssh::create_bsss_config_file
    printf '%s\0' "$new_port" | ufw::add_bsss_rule
    printf '%s\0' "$new_port"
}

# @type:        Source
# @description: Запрашивает у пользователя новый SSH порт
# @params:      нет
# @stdin:       нет
# @stdout:      port\0
# @exit_code:   0 - успешно
#               $? - ошибка
ssh::ask_new_port() {
    local port_pattern="^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"

    local suggested_port
    suggested_port=$(ssh::generate_free_random_port) || return

    local new_port
    while true; do
        new_port=$(io::ask_value "Введите новый SSH порт" "$suggested_port" "$port_pattern" "1-65535, Enter для $suggested_port" | tr -d '\0') || return
        ssh::is_port_busy "$new_port" || { printf '%s\0' "$new_port"; break; }
        log_error "SSH порт $new_port уже занят другим сервисом."
    done
}

# @type:        Orchestrator
# @description: Выводит список найденных конфигураций и связанных с ними портов
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - логика успешно отработала
#               $? - если в дочерних функциях произошел сбой
ssh::log_bsss_configs() {
    local path
    local port
    local found=0

    while IFS= read -r -d '' path || break; do

        if (( found == 0 )); then
            log_info "Есть правила ${UTIL_NAME^^} для SSH:"
            found=$((found + 1))
        fi

        port=$(printf '%s\0' "$path" | ssh::get_first_port_from_path | tr -d '\0')
        log_info_simple_tab "$(log::path_and_port_template "$path" "$port")"

    done < <(sys::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK")

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
ssh::log_all_configs_w_port() {
    local grep_result
    local found=0

    while IFS= read -r grep_result || break; do

        if (( found == 0 )); then
            log_info "Есть сторонние правила SSH:"
            found=$((found + 1))
        fi

        log_info_simple_tab "$(printf '%s' $grep_result)"

    done < <(grep -EiH --exclude="${SSH_CONFIGD_DIR%/}"/$BSSS_SSH_CONFIG_FILE_MASK '^\s*port\b' "${SSH_CONFIGD_DIR%/}"/$SSH_CONFIG_FILE_MASK "$SSH_CONFIG_FILE" || true)

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
orchestrator::actions_after_port_change() {
    sys::restart_services

    log::draw_lite_border
    log_info "Актуальная информация после внесения изменений"
    ssh::log_active_ports_from_ss
    ssh::log_bsss_configs
    ufw::log_active_ufw_rules
}

# @type:        Orchestrator
# @description: Выводит активные правила UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log_active_ufw_rules() {
    local rule
    local found=0

    while read -r -d '' rule || break; do

        if (( found == 0 )); then
            log_info "Есть правила UFW [ufw show added]"
            found=$((found + 1))
        fi
        log_info_simple_tab "$rule"

    done < <(ufw::get_all_rules)

    if (( found == 0 )); then
        log_info "Нет правил UFW [ufw show added]"
    fi
}


# @type:        Filter
# @description: Удаляет все правила BSSS и передает порт дальше
# @params:      нет
# @stdin:       port\0 (опционально)
# @stdout:      port\0 (опционально)
# @exit_code:   0 - успешно
ssh::reset_and_pass() {
    local port=""

    # || true нужен что бы гасить код 1 при false кода [[ ! -t 0 ]]
    [[ ! -t 0 ]] && IFS= read -r -d '' port || true
    
    ssh::delete_all_bsss_rules

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}

# @type:        Filter
# @description: Удаляет все правила UFW BSSS и передает порт дальше
# @params:      нет
# @stdin:       port\0 (опционально)
# @stdout:      port\0 (опционально)
# @exit_code:   0 - успешно
ufw::reset_and_pass() {
    local port=""

    # || true нужен что бы гасить код 1 при false кода [[ ! -t 0 ]]
    [[ ! -t 0 ]] && IFS= read -r -d '' port || true
    
    ufw::delete_all_bsss_rules

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}

# @type:        Orchestrator
# @description: Удаляет все правила BSSS SSH
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ssh::delete_all_bsss_rules() {
    # || true нужен потому что sys::get_paths_by_mask может возвращать пустоту и read зависает
    sys::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | sys::delete_paths || true
}

# @type:        Filter
# @description: Удаляет указанные файлы и директории
# @params:      нет
# @stdin:       path\0 (0..N)
# @stdout:      нет
# @exit_code:   0 - всегда
sys::delete_paths() {
    while IFS= read -r -d '' path || break; do
        local resp
        resp=$(rm -rfv -- "$path" ) || return
        log_info "Удалено: $resp"
    done
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
ssh::is_port_busy() {
    ss -ltn | grep -qE ":$1([[:space:]]|$)"
}

# @type:        Source
# @description: Генерирует случайный свободный порт в диапазоне 10000-65535
# @params:      нет
# @stdin:       нет
# @stdout:      port
# @exit_code:   0 - порт успешно сгенерирован
#               $? - ошибка
ssh::generate_free_random_port() {
    while IFS= read -r port || break; do
        if ! ssh::is_port_busy "$port"; then
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
ssh::create_bsss_config_file() {
    local path="${SSH_CONFIGD_DIR%/}/$BSSS_SSH_CONFIG_FILE_NAME"
    local port
    read -r -d '' port
    
    # Создаем файл с настройкой порта
    if cat > "$path" << EOF
# $BSSS_MARKER_COMMENT
# SSH port configuration
Port $port
EOF
    then
        log_info "Создано правило SSH: $(log::path_and_port_template $path $port)"
    else
        log_error "Не удалось создать правило SSH: $path"
        return 1
    fi
}

# @type:        Filter
# @description: Форматирует строку для вывода пути к файлу и порта
# @params:
#   path        Путь к файлу
#   port        Номер порта
# @stdin:       нет
# @stdout:      Отформатированная строка
# @exit_code:   0 - всегда
log::path_and_port_template() {
    printf '%s\n' "$1 Порт: $2"
}

# @type:        Orchestrator
# @description: Удаляет все правила UFW BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::delete_all_bsss_rules() {
    # local found_any=0

    local rule_args
    while IFS= read -r -d '' rule_args || break; do
        # found_any=1

        if printf '%s' "$rule_args" | xargs ufw --force delete >> err.log 2>&1; then
            log_info "Удалено правило UFW: ufw --force delete $rule_args"
        else
            log_error "Ошибка при удалении правила UFW: ufw --force delete $rule_args"
        fi
    done < <(ufw::get_all_bsss_rules)

    # if (( found_any == 0 )); then
    #     log_info "Активных правил ${UTIL_NAME^^} для UFW не обнаружено, синхронизация не требуется."
    # fi
}

# @type:        Source
# @description: Получает все правила UFW BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      rule\0 (0..N)
# @exit_code:   0 - всегда
ufw::get_all_bsss_rules() {
    ufw show added \
    | awk -v marker="^ufw.*comment[[:space:]]+\x27$BSSS_MARKER_COMMENT\x27" '
        BEGIN { ORS="\0" }
        $0 ~ marker {
            sub(/^ufw[[:space:]]+/, "");
            print $0;
        }
    '
}

# @type:        Source
# @description: Получает все правила UFW
# @params:      нет
# @stdin:       нет
# @stdout:      rule\0 (0..N)
# @exit_code:   0 - всегда
ufw::get_all_rules() {
    if command -v ufw > /dev/null 2>&1; then
        ufw show added \
        | awk -v marker="^ufw.*" '
            BEGIN { ORS="\0" }
            $0 ~ marker {
                print $0;
            }
        '
    fi
}

# @type:        Filter
# @description: Добавляет правило UFW для BSSS
# @params:      нет
# @stdin:       port\0 (0..N)
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::add_bsss_rule() {
    local port
    while read -r -d '' port; do
        if ufw allow "${port}"/tcp comment "$BSSS_MARKER_COMMENT" >> err.log 2>&1; then
            log_info "Создано правило UFW: ufw allow ${port}/tcp comment $BSSS_MARKER_COMMENT"
        else
            log_info "Ошибка при добавлении правила UFW: ufw allow ${port}/tcp comment $BSSS_MARKER_COMMENT"
        fi
    done
 
}

# @type:        Filter
# @description: Деактивирует UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::force_disable() {
    ufw --force disable >/dev/null 2>&1
    log_success "UFW: Полностью деактивирован [ufw --force disable]"
}

# @type:        Orchestrator
# @description: Полная очистка системы от следов BSSS и деактивация UFW.
#               Вызывается при критическом сбое или таймауте.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::total_rollback() {
    log_warn "ROLLBACK: Инициирован полный демонтаж настроек BSSS..."

    ssh::delete_all_bsss_rules
    ufw::force_disable
    ufw::delete_all_bsss_rules
    orchestrator::actions_after_port_change
    
    log_success "ROLLBACK: Система возвращена к исходному состоянию. Проверьте доступ по старым портам."
}

# @type:        Orchestrator
# @description: Фоновый процесс-таймер. Не зависит от жизни родительской сессии.
# @params:      $1 - PID родителя (скрипта)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::watchdog_timer() {
    local main_script_process_id="$1"
    log_info "watchdog: ожидание $ROLLBACK_TIMER_SECONDS сек..."
    sleep "$ROLLBACK_TIMER_SECONDS"
    log_info "watchdog: останавливаем процесс $main_script_process_id"
    kill "$main_script_process_id" 2>/dev/null || true
    orchestrator::total_rollback
}
