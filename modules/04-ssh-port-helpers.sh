#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# @type:        Action
# @description: Основной функционал установки/изменения SSH порта.
#               Запрашивает у пользователя порт, проверяет его доступность,
#               удаляет старые конфигурации (если требуется) и создает новую.
# @params:      $@ — список путей к существующим конфигурационным файлам (передается в delete_paths через поток).
# @stdin:       Не используется напрямую (но передает $@ через printf в delete_paths).
# @stdout:      Логи процесса в stderr.
# @stderr:      Логи процесса и сообщения об ошибках.
# @exit_code:   0 — порт успешно установлен; 1+ — ошибка в процессе.
action_restore_and_install_new_port() {
    local new_port
    new_port=$(get_new_port) || return

    action_restore_default "$@"

    printf '%s\n' "$new_port" | create_new_ssh_config_file
    printf '%s\n' "$new_port" | ufw_add_bsss_rule
}

get_new_port() {
    local port_pattern="^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"

    local suggested_port
    suggested_port=$(get_free_random_port) || return

    local new_port
    while true; do
        new_port=$(ask_value "Введите новый порт" "$suggested_port" "$port_pattern" "1-65535, Enter для $suggested_port") || return
        is_port_busy "$new_port" || { printf '%s\n' "$new_port"; break; }
        log_error "Порт $new_port уже занят другим сервисом."
    done
}

# @type:        Reporter
# @description: Выводит список найденных конфигураций и связанных с ними портов.
# @params:      Список путей к файлам.
# @stdin:       Не используется.
# @stdout:      Текстовый отчет в stderr (логи).
# @stderr:      Текстовый отчет в stderr (логи).
# @exit_code:   0 — логика успешно отработала; 1+ — если в дочерних функциях произошел сбой.
show_bsss_configs() {
    log_info "Найдены правила ${UTIL_NAME^^}:"

    printf '%s\0' "$@" \
    | while IFS= read -r -d '' path; do
        port=$(printf '%s\n' "$path" | get_ssh_port_from_path)
        log_info_simple_tab "$(path_and_port_template "$path" "$port")"
    done
}

# @type:        Action
# @description: Выполняет действия после установки порта: перезапуск сервисов и валидация.
# @params:      Не принимает параметры.
# @stdin:       Не используется.
# @stdout:      Зависит от вызываемых функций.
# @stderr:      Зависит от вызываемых функций.
# @exit_code:   0 — действия успешно выполнены; 1+ — ошибка в процессе.
actions_after_port_install() {
    restart_services
    check_ssh_ports_availability
}

# @type:        Action
# @description: Восстанавливает настройки по умолчанию путем удаления конфигурационных файлов.
# @params:      Список путей к файлам для удаления.
# @stdin:       Не используется.
# @stdout:      Зависит от вызываемых функций.
# @stderr:      Зависит от вызываемых функций.
# @exit_code:   0 — настройки успешно сброшены; 1+ — ошибка в процессе.
action_restore_default() {
    ssh_delete_all_bsss_rules "$@"
    ufw_delete_all_bsss_rules
}

ssh_delete_all_bsss_rules() {
    printf '%s\0' "$@" | delete_paths
}

# UPDATE
# @type:        Action
# @description: Удаляет указанные файлы и директории.
# @params:      Список путей к файлам/директориям для удаления.
# @stdin:       NUL-separated paths
# @stdout:      Логи процесса удаления.
# @stderr:      Ошибки удаления (если возникнут).
# @exit_code:   Всегда 0 (ошибки не прерывают выполнение).
delete_paths() {
    xargs -r0 rm -rfv \
    | while IFS= read -r line; do
        [[ -n "$line" ]] && log_info "Успешно: $line"
    done
}

# @type:        Action
# @description: Перезапускает SSH сервис после проверки конфигурации.
# @params:      Не принимает параметры.
# @stdin:       Не используется.
# @stdout:      Логи процесса перезапуска.
# @stderr:      Сообщения об ошибках конфигурации.
# @exit_code:   0 — сервис успешно перезапущен; 1 — ошибка конфигурации.
restart_services() {
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
is_port_busy() {
    ss -ltn | grep -qE ":$1([[:space:]]|$)"
}

# @type:        Generator
# @description: Генерирует случайный свободный порт в диапазоне 10000-65535.
# @params:      Не принимает параметры.
# @stdin:       Не используется.
# @stdout:      Сгенерированный номер порта.
# @stderr:      Не используется.
# @exit_code:   0 — порт успешно сгенерирован; 1+ — ошибка (теоретически невозможна).
get_free_random_port() {
    while IFS= read -r port; do
        if ! is_port_busy "$port"; then
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
create_new_ssh_config_file() {
    local path="${SSH_CONFIGD_DIR%/}/$BSSS_SSH_CONFIG_FILE_NAME"
    local port
    read -r port
    


    # Создаем файл с настройкой порта
    if cat > "$path" << EOF
# "$BSSS_MARKER_COMMENT"
# SSH port configuration
Port "$port"
EOF
    then
        log_info "Правило SSH создано: $(path_and_port_template $path $port)"
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
path_and_port_template() {
    printf '%s\n' "$1 Порт: $2"
}

ufw_delete_all_bsss_rules() {
    local found_any=0

    local rule_args
    while IFS= read -r -d '' rule_args; do
        found_any=1

        if printf '%s' "$rule_args" | xargs ufw --force delete >> err.log 2>&1; then
            log_info "Успешно: ufw --force delete $rule_args"
        else
            log_error "Ошибка: ufw --force delete $rule_args"
        fi
    done < <(
        ufw show added \
        | awk -v marker="^ufw.*comment[[:space:]]+$BSSS_MARKER_COMMENT" '
            BEGIN { ORS="\0" }
            $0 ~ marker {
                sub(/^ufw[[:space:]]+/, "");
                print $0;
            }
        '
    )

    if (( found_any == 0 )); then
        log_info "Активных правил ${UTIL_NAME^^} для ufw не обнаружено, синхронизация не требуется."
    fi
}

ufw_add_bsss_rule() {
    local port
    while read -r port; do
        [[ ! "$port" =~ ^-?[0-9]+$ ]]
        if ufw allow "${port}"/tcp comment "$BSSS_MARKER_COMMENT" >> err.log 2>&1; then
            log_info "Успешно: ufw allow "${port}"/tcp comment $BSSS_MARKER_COMMENT"
        else
            log_info "Ошибка: ufw allow "${port}"/tcp comment $BSSS_MARKER_COMMENT"
        fi
    done
 
}

validate_ssh_port() {
    if [[ -z "$port" ]]; then
        log_error "Не указан порт SSH для конфигурационного файла"
        return 1
    elif [[ ! "$port" =~ ^-?[0-9]+$ ]]; then
        log_error "Порт SSH не является числом [$port]"
    fi
}