# @type:        Sink
# @description: Вращает лог-файлы - удаляет старые файлы если их больше MAX_LOG_FILES
#               Если каталога не существует - ничего не делает
#               Если каталог существует, но нет логов - ничего не делает
#               Если файлов <= MAX_LOG_FILES - ничего не делает
#               Если файлов > MAX_LOG_FILES - удаляет самые ранние файлы по дате модификации
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
sys::log::rotate_old_files() {
    local logs_dir="${PROJECT_ROOT}/${LOGS_DIR}"
    [[ ! -d "$logs_dir" ]] && return 0
    
    find "$logs_dir" -maxdepth 1 -type f -name "[0-9][0-9][0-9][0-9]-*.log" -printf '%T@ %p\0' \
        | sort -z -n \
        | sed -z 's/^[0-9.]* //' \
        | head -z -n -"$MAX_LOG_FILES" \
        | xargs -r0 rm -f
}


# @type:        Source
# @description: Получает список путей через нулевой разделитель
# @params:
#   dir         [optional] Directory to search in (default: current directory)
#   mask        [optional] Glob pattern (default: "*")
# @stdin:       нет
# @stdout:      path\0 (0..N)
# @exit_code:   0
#               1 - при отсутствии файлов по маске
sys::file::get_paths_by_mask() {
    local dir=${1:-.}
    local mask=${2:-*}

    (
        shopt -s nullglob
        local files=("${dir%/}/"$mask)
        (( ${#files[@]} > 0 )) && printf '%s\0' "${files[@]}"
    )
}

# @type:        Filter
# @description: Возвращает строку - путь с типом и порядком запуска
# @params:      нет
# @stdin:       path\0 (0..N)
# @stdout:      path\torder\ttype\0 (0..N)
# @exit_code:   0 - всегда
sys::module::get_paths_w_type () {
    xargs -r0 gawk '
        BEGIN { IGNORECASE=1; ORS="\0"; order=""; type="" }
        /^# MODULE_ORDER:/ { order=$3; next }
        /^# MODULE_TYPE:/ {
            type=$3
            print FILENAME "\t" order "\t" type
            nextfile
        }
    '
}

# @type:        Filter
# @description: Возвращает отфильтрованные по типу пути к модулям
# @params:
#   type        Module type
# @stdin:       path\torder\ttype\0 (0..N)
# @stdout:      path\torder\ttype\0 (0..N)
# @exit_code:   0 - всегда
sys::module::get_by_type () {
    gawk -v type="$1" -v RS='\0' -F'\t' '
        type == $3 { printf "%s\0", $0 }
    '
}

# @type:        Filter
# @description: Сортирует пути модулей по приоритету MODULE_ORDER и извлекает только пути
# @params:      нет
# @stdin:       path\torder\ttype\0 (0..N)
# @stdout:      path\0 (0..N)
# @exit_code:   0 - всегда
sys::module::sort_by_order() {
    sort -z -t$'\t' -k2,2n | cut -z -f1
}

# @type:        Source
# @description: Валидирует наличие обязательного метатега MODULE_ORDER во всех модулях с MODULE_TYPE
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - все модули валидны
#               5 - найдены модули без MODULE_ORDER
sys::module::validate_order() {
    local missing=0

    while IFS= read -r -d '' path; do
        if ! grep -q '^# MODULE_ORDER:' "$path"; then
            log_error "$(_ "common.helpers.validate_order.error_missing_tag" "$path")"
            missing=1
        fi
    done < <(sys::file::get_paths_by_mask "${PROJECT_ROOT}/$MODULES_DIR" "$MODULES_MASK" \
    | sys::module::get_paths_w_type \
    | gawk -v RS='\0' -F'\t' 'BEGIN { ORS="" } { print $1 "\0" }')

    (( missing )) && return 5 || return 0
}

# @type:        Source
# @description: Проверяет дубликаты значений MODULE_ORDER в модулях
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - нет дубликатов
#               5 - найдены дубликаты MODULE_ORDER
sys::module::check_duplicate_order() {
    local duplicates
    local has_dup=0

    duplicates=$(grep -EiHs '^# MODULE_ORDER:' "${PROJECT_ROOT}/$MODULES_DIR"/*.sh \
    | gawk -F': ' '{print $2}' | sort | uniq -d) || true

    if [[ -n "$duplicates" ]]; then
        has_dup=1
        for value in $duplicates; do
            grep -EiHs "^# MODULE_ORDER: ${value}$" "${PROJECT_ROOT}/$MODULES_DIR"/*.sh \
            | cut -d: -f1 \
            | while IFS= read -r file; do
                log_error "$(_ "common.helpers.validate_order.error_duplicate" "$value" "$file")"
            done
        done
    fi

    (( has_dup )) && return 5 || return 0
}

# @type:        Filter
# @description: Удаляет указанные файлы и директории
# @params:      нет
# @stdin:       path\0 (0..N)
# @stdout:      нет
# @exit_code:   0
#               1 - ошибка при удалении
sys::file::delete() {
    local path
    local resp
    while IFS= read -r -d '' path; do
        [[ ! -e "$path" ]] && continue

        if resp=$(rm -rfv "$path" 2>&1); then
            log_info "$(_ "common.helpers.file.delete.success" "$resp")"
        else
            log_error "$(_ "common.helpers.file.delete.error" "$path" "$resp")"
            return 1
        fi
    done
}

# @type:        Source
# @description: Получает активные SSH порты из ss
# @params:      нет
# @stdin:       нет
# @stdout:      port\0 (0..N)
# @exit_code:   0 - всегда
ssh::port::get_from_ss() {
    ss -Hltnp | gawk '
        BEGIN { ORS="\0" }
        /"sshd"/ {
            if (match($4, /:[0-9]+$/, m)) {
                print substr(m[0], 2)
            }
        }
    ' | sort -zu
}

# @type:        Orchestrator
# @description: Проверяет возможность определения активных портов
# @params:
#   strict_mode [optional] Строгий режим вызывающий ошибку 1 при недоступности портов
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - порты определены
#               1 - порты не определены
ssh::log::active_ports_from_ss() {
    local strict_mode=${1:-0}

    local active_ports=""
    active_ports=$(ssh::port::get_from_ss | tr '\0' ',' | sed 's/,$//')

    if [[ -z "$active_ports" ]]; then
        log_error "$(_ "common.helpers.ssh.no_active_ports")"
        (( strict_mode == 1 )) && return 1
    else
        log_info "$(_ "common.helpers.ssh.active_ports" "$active_ports")"
    fi

}

# @type:        Orchestrator
# @description: Запускает фоновый процесс rollback (watchdog)
# @params:
#   watchdog_fifo путь к FIFO для коммуникации
# @stdin:       нет
# @stdout:      PID процесса watchdog
# @exit_code:   0 - успешно
rollback::orchestrator::watchdog_start() {
    local rollback_type="$1"
    local rollback_module="${PROJECT_ROOT}/${UTILS_DIR}/$ROLLBACK_MODULE_NAME"

    # Сторож в фоне
    nohup bash "$rollback_module" "$rollback_type" "$$" "$WATCHDOG_FIFO" >/dev/null 2>&1 &
    printf '%s' $! # Возвращаем PID для оркестратора
}

# @type:        Orchestrator
# @description: Останавливает процесс rollback (watchdog) по PID
# @params:
#   watchdog_pid PID процесса watchdog для остановки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
rollback::orchestrator::watchdog_stop() {
    # Посылаем сигнал успешного завершения (USR1)
    log_info "$(_ "common.helpers.rollback.stop_signal" "$WATCHDOG_PID")"
    kill -USR1 "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
    printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
}

# @type:        Orchestrator
# @description: Создает FIFO и запускает слушатель для коммуникации с rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
make_fifo_and_start_reader() {
    mkfifo "$WATCHDOG_FIFO"
    log_info "$(_ "common.helpers.rollback.fifo_created" "$WATCHDOG_FIFO")"
    cat "$WATCHDOG_FIFO" >&2 &
}

# @type:        Orchestrator
# @description: Обработчик сигнала SIGUSR1 - останавливает модуль при откате и удаляем fifo
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   3 - код завершения при откате
common::rollback::stop_script_by_rollback_timer() {
    log_info "$(_ "common.helpers.rollback.stop_received")"
    printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
    exit 3
}

# @type:        Orchestrator
# @description: Обработчик сигнала EXIT - останавливает модуль и удаляем fifo
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   $?
common::exit::actions() {
    local rc=$?
    log_info "$(_ "common.helpers.rollback.exit_received" "$rc")"
    [[ -n "$WATCHDOG_FIFO" ]] && printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
    log_stop
    exit $rc
}

# @type:        Orchestrator
# @description: Обработчик сигнала INT
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   $?
common::int::actions() {
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        rc=130
    fi
    new_line
    log_info "$(_ "common.helpers.rollback.int_received" "$rc")"
    exit $rc
}

# @type:        Sink
# @description: Обработчик ошибки pipe
# @params:      error_code
# @stdin:       нет
# @stdout:      нет
# @exit_code:   2
#               130
#               $?
common::pipefail::fallback() {
    local rc_pipe=("$@")
    local final_rc=1

    for rc in "${rc_pipe[@]}"; do
        if [[ "$rc" == "2" || "$rc" == "130" ]]; then
            final_rc=$rc
            break
        fi
    done
    
    log_info "$(_ "common.pipefail.interrupted" "$final_rc")"
    case $final_rc in
        2|130) return $final_rc ;; # Пробрасываем код 2/130
        *) return 1 ;; # Неизвестная ошибка
    esac
}

# @type:        Source
# @description: Возвращает метод подключения пользователя [logname]
# @params:      нет
# @stdin:       нет
# @stdout:      connection_type\0 (PUBLICKEY/PASSWORD/UNKNOWN)
# @exit_code:   0
sys::user::get_auth_method() {
    local auth_info

    auth_info=$(journalctl _COMM=sshd --since "72h ago" 2>/dev/null | grep "Accepted" | grep "for $(logname)" | tail -1)

    if [[ "$auth_info" == *"publickey"* ]]; then
        printf '%s\0' "key"
    elif [[ "$auth_info" == *"password"* ]] || [[ "$auth_info" == *"keyboard-interactive"* ]]; then
        printf '%s\0' "pass"
    elif [[ -z "$auth_info" ]]; then
        printf '%s\0' "timeout"
    else
        printf '%s\0' "n/a"
    fi
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

# @type:        Filter
# @description: Удаляет все правила UFW BSSS и передает порт дальше
# @params:      нет
# @stdin:       port\0 (опционально)
# @stdout:      port\0 (опционально)
# @exit_code:   0 - успешно
ufw::rule::reset_and_pass() {
    local port=""

    # || true нужен что бы гасить код 1 при false кода [[ ! -t 0 ]]
    [[ ! -t 0 ]] && read -r -d '' port || true

    ufw::rule::delete_all_bsss

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}

# @type:        Sink
# @description: Удаляет все правила UFW BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::rule::delete_all_bsss() {
    local rule_args
    while IFS= read -r -d '' rule_args || break; do

        if printf '%s' "$rule_args" | xargs ufw --force delete >/dev/null 2>&1; then
            log_info "$(_ "common.helpers.ufw.rule.deleted" "$rule_args")"
        else
            log_error "$(_ "common.helpers.ufw.rule.delete_error" "$rule_args")"
        fi
    done < <(ufw::rule::get_all_bsss)
}

# @type:        Source
# @description: Получает все правила UFW BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      rule\0 (0..N)
# @exit_code:   0 - всегда
ufw::rule::get_all_bsss() {
    ufw show added \
    | gawk -v marker="^ufw.*comment[[:space:]]+\x27$BSSS_MARKER_COMMENT\x27" '
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
ufw::rule::get_all() {
    if command -v ufw > /dev/null 2>&1; then
        ufw show added \
        | gawk -v marker="^ufw.*" '
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
ufw::rule::add_bsss() {
    local port
    while read -r -d '' port; do
        if ufw allow "${port}"/tcp comment "$BSSS_MARKER_COMMENT" >/dev/null 2>&1; then
            log_info "$(_ "common.helpers.ufw.rule.added" "$port")"
        else
            log_info "$(_ "common.helpers.ufw.rule.add_error" "$port")"
        fi
    done
}

# @type:        Filter
# @description: Проверяет, активен ли UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - UFW активен
#               1 - UFW неактивен
ufw::status::is_active() {
    ufw status | grep -wq active
}

# @type:        Filter
# @description: Деактивирует UFW (пропускает если уже деактивирован)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::status::force_disable() {
    if ufw::status::is_active && ufw --force disable >/dev/null 2>&1; then
        log_info "$(_ "common.helpers.ufw.disabled")"
    else
        log_info "$(_ "common.helpers.ufw.already_disabled")"
    fi
}

# @type:        Validator
# @description: Проверяет, существует ли бэкап файл настроек PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - бэкап существует (PING отключен)
#               1 - бэкап не существует (PING не отключен)
ufw::ping::is_configured() {
    [[ -f "$UFW_BEFORE_RULES_BACKUP" ]]
}

# @type:        Orchestrator
# @description: Восстанавливает файл before.rules из бэкапа и удаляет бэкап
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно восстановлено
#               $? - код ошибки cp или rm
ufw::ping::restore() {
    if res=$(cp -pv "$UFW_BEFORE_RULES_BACKUP" "$UFW_BEFORE_RULES" 2>&1); then
        log_info "$(_ "ufw.success.backup_restored" "$res")"
    # else
    #     local rc=$?
    #     log_error "$(_ "ufw.error.restore_failed" "$UFW_BEFORE_RULES" "$res")"
    #     return "$rc"
    fi

    printf '%s\0' "$UFW_BEFORE_RULES_BACKUP" | sys::file::delete
}

# @type:        Orchestrator
# @description: Выводит активные правила UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log::rules() {
    local rule
    local found=0

    while read -r -d '' rule || break; do

        if (( found == 0 )); then
            log_info "$(_ "common.helpers.ufw.rules_found")"
            log_bold_info "$(_ "common.helpers.ufw.rules.sync")"
            log_bold_info "$(_ "common.helpers.ufw.rules.delete_warning")"
            found=$((found + 1))
        fi
        log_info_simple_tab "$(_ "no_translate" "$rule")"

    done < <(ufw::rule::get_all)

    if (( found == 0 )); then
        log_info "$(_ "common.helpers.ufw.rules_not_found")"
    fi
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
# @description: Отображает статусы ufw: BSSS правила, сторонние правила
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - Всегда успешно
ufw::orchestrator::log_statuses() {
    ufw::log::status
    ufw::log::rules
    ufw::log::ping_status
}
