#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# @type:        Action
# @description: Основной функционал установки/изменения SSH порта.
#               Запрашивает у пользователя порт, проверяет его доступность,
#               удаляет старые конфигурации (если требуется) и создает новую.
# @params:      $@ — список путей к существующим конфигурационным файлам (передается в sys::delete_paths через поток).
# @stdin:       Не используется напрямую (но передает $@ через printf в sys::delete_paths).
# @stdout:      Логи процесса в stderr.
# @stderr:      Логи процесса и сообщения об ошибках.
# @exit_code:   0 — порт успешно установлен; 1+ — ошибка в процессе.
ssh::install_new_port() {
    local new_port
    read -r -d '' new_port

    printf '%s\0' "$new_port" | ssh::create_config_file
    printf '%s\0' "$new_port" | ufw::add_bsss_rule
}

ssh::ask_new_port() {
    local port_pattern="^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"

    local suggested_port
    suggested_port=$(ssh::generate_free_random_port) || return

    local new_port
    while true; do
        new_port=$(io::ask_value "Введите новый SSH порт" "$suggested_port" "$port_pattern" "1-65535, Enter для $suggested_port") || return
        ssh::is_port_busy "$new_port" || { printf '%s\0' "$new_port"; break; }
        log_error "SSH порт $new_port уже занят другим сервисом."
    done
}

# @type:        Source
# @description: Выводит список найденных конфигураций и связанных с ними портов.
# @params:      Список путей к файлам.
# @stdin:       Не используется.
# @stdout:      Текстовый отчет в stderr (логи).
# @stderr:      Текстовый отчет в stderr (логи).
# @exit_code:   0 — логика успешно отработала; 1+ — если в дочерних функциях произошел сбой.
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

# @type:        Action
# @description: Выполняет действия после установки порта: перезапуск сервисов и валидация.
# @params:      Не принимает параметры.
# @stdin:       Не используется.
# @stdout:      Зависит от вызываемых функций.
# @stderr:      Зависит от вызываемых функций.
# @exit_code:   0 — действия успешно выполнены; 1+ — ошибка в процессе.
orchestrator::actions_after_port_install() {
    sys::restart_services

    log::draw_border
    log_info "Актуальная информация после внесения изменений"
    ssh::log_active_ports_from_ss
    ssh::log_bsss_configs
    ufw::log_active_ufw_rules
}

# @type:        Source
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



ssh::reset_and_pass() {
    local port=""

    # || true нужен что бы гасить код 1 при false кода [[ ! -t 0 ]]
    [[ ! -t 0 ]] && IFS= read -r -d '' port || true
    
    ssh::delete_all_bsss_rules

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}

ufw::reset_and_pass() {
    local port=""

    # || true нужен что бы гасить код 1 при false кода [[ ! -t 0 ]]
    [[ ! -t 0 ]] && IFS= read -r -d '' port || true
    
    ufw::delete_all_bsss_rules

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}

ssh::delete_all_bsss_rules() {
    # || true нужен потому что sys::get_paths_by_mask может возвращать пустоту и read зависает
    sys::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | sys::delete_paths || true
}

# UPDATE
# @type:        Action
# @description: Удаляет указанные файлы и директории.
# @params:      Список путей к файлам/директориям для удаления.
# @stdin:       NUL-separated paths
# @stdout:      Логи процесса удаления.
# @stderr:      Ошибки удаления (если возникнут).
# @exit_code:   Всегда 0 (ошибки не прерывают выполнение).
sys::delete_paths() {
    while IFS= read -r -d '' path || break; do
        local resp
        resp=$(rm -rfv -- "$path" ) || return
        log_info "Удалено: $resp"
    done
}



# @type:        Action
# @description: Перезапускает SSH сервис после проверки конфигурации.
# @params:      Не принимает параметры.
# @stdin:       Не используется.
# @stdout:      Логи процесса перезапуска.
# @stderr:      Сообщения об ошибках конфигурации.
# @exit_code:   0 — сервис успешно перезапущен; 1 — ошибка конфигурации.
sys::restart_services() {
    if sshd -t; then
        systemctl daemon-reload && log_info "Конфигурация перезагружена [systemctl daemon-reload]"
        systemctl restart ssh && log_info "SSH сервис перезагружен [systemctl restart ssh]"
    else
        log_error "Ошибка конфигурации ssh [sshd -t]"
        return 1
    fi
}

# @type:        Checker
# @description: Проверяет, занят ли указанный порт.
# @params:      $1 - номер порта для проверки.
# @stdin:       Не используется.
# @stdout:      Не используется.
# @stderr:      Не используется.
# @exit_code:   0 — порт свободен; 1 — порт занят.
ssh::is_port_busy() {
    ss -ltn | grep -qE ":$1([[:space:]]|$)"
}

# @type:        Generator
# @description: Генерирует случайный свободный порт в диапазоне 10000-65535.
# @params:      Не принимает параметры.
# @stdin:       Не используется.
# @stdout:      Сгенерированный номер порта.
# @stderr:      Не используется.
# @exit_code:   0 — порт успешно сгенерирован; 1+ — ошибка (теоретически невозможна).
ssh::generate_free_random_port() {
    while IFS= read -r port || break; do
        if ! ssh::is_port_busy "$port"; then
            printf '%s\n' "$port"
            return
        fi
    done < <(shuf -i 10000-65535)
}

# @type:        Creator
# @description: Создает новый конфигурационный файл SSH с указанным портом.
# @params:      $1 - номер порта для настройки.
# @stdin:       Не используется.
# @stdout:      Логи процесса создания.
# @stderr:      Сообщения об ошибках.
# @exit_code:   0 — файл успешно создан; 1 — ошибка создания.
ssh::create_config_file() {
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

# @type:        Formatter
# @description: Форматирует строку для вывода пути к файлу и порта.
# @params:      $1 - путь к файлу, $2 - номер порта.
# @stdin:       Не используется.
# @stdout:      Отформатированная строка.
# @stderr:      Не используется.
# @exit_code:   Всегда 0.
log::path_and_port_template() {
    printf '%s\n' "$1 Порт: $2"
}

ufw::delete_all_bsss_rules() {
    local found_any=0

    local rule_args
    while IFS= read -r -d '' rule_args || break; do
        found_any=1

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


