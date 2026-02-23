# @type:        Source
# @description: Получает список путей через нулевой разделитель
# @params:      dir Директория для поиска (string\n)
#               mask Маска файлов nullglob (string\n)
# @stdin:       нет
# @stdout:      path\0 (0..N)
# @exit_code:   0 успех
#               1 при отсутствии файлов по маске
sys::file::get_paths_by_mask() {
    local dir="$1"
    local mask=$2 # nullglob mask

    (
        shopt -s nullglob
        local files=("${dir%/}/"$mask)
        (( ${#files[@]} > 0 )) && printf '%s\0' "${files[@]}"
    )
}

# @type:        Filter
# @description: Удаляет указанные файлы и директории
# @stdin:       path\0 (0..N)
# @stdout:      нет
# @exit_code:   0 успех
#               1 ошибка при удалении
sys::file::delete() {
    local path
    local resp
    while IFS= read -r -d '' path; do
        [[ ! -e "$path" ]] && continue

        if resp=$(rm -rfv "$path" 2>&1); then
            log_info "$(_ "common.delete.success" "$resp")"
        else
            log_error "$(_ "common.delete.error" "$path")"
            return 1
        fi
    done
}

# @type:        Source
# @description: Получает активные SSH порты из ss
# @stdin:       нет
# @stdout:      port\0 (0..N)
# @exit_code:   0 всегда успешно
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
# @params:      strict_mode Режим строгой проверки (num\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 порты определены
#               1 порты не определены
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
# @params:      rollback_type Тип отката (string\n)
#               quiet Флаг тихого режима (string)
# @stdin:       нет
# @stdout:      PID процесса watchdog
# @exit_code:   0 успех
rollback::orchestrator::watchdog_start() {
    local rollback_type="$1"
    local quiet="${2:-}"
    local rollback_module="${PROJECT_ROOT}/${UTILS_DIR}/$ROLLBACK_MODULE_NAME"

    nohup bash "$rollback_module" "$rollback_type" "$$" "$WATCHDOG_FIFO" "$SYNC_FIFO" "$quiet" >/dev/null 2>&1 &
    printf '%s' $!
}

# @type:        Orchestrator
# @description: Останавливает процесс rollback (watchdog) по PID
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
rollback::orchestrator::watchdog_stop() {
    # Посылаем сигнал успешного завершения (USR1)
    log_info "$(_ "common.helpers.rollback.stop_signal" "$WATCHDOG_PID")"
    # || true: WATCHDOG_PID может уже не существовать
    log_info "$(_ "rollback.signal_usr1_sent")"
    kill -USR1 "$WATCHDOG_PID" 2>/dev/null || true
    # || true: Процесс может уже завершиться к моменту вызова wait
    wait "$WATCHDOG_PID" 2>/dev/null || true
    printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
}

# @type:        Orchestrator
# @description: Создает FIFO и запускает слушатель для коммуникации с rollback
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
make_fifo_and_start_reader() {
    mkfifo "$WATCHDOG_FIFO"
    log_info "$(_ "common.helpers.rollback.fifo_created" "$WATCHDOG_FIFO")"
    cat "$WATCHDOG_FIFO" >&3 &
}

# @type:        Orchestrator
# @description: Создает FIFO для подтверждения готовности rollback
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
start_sync_rollback() {
    mkfifo "$SYNC_FIFO"
    log_info "$(_ "rollback.fifo_created" "$SYNC_FIFO")"
}

# @type:        Orchestrator
# @description: Ожидает подтверждения готовности rollback и удаляет FIFO
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
stop_sync_rollback() {
    log_info "$(_ "rollback.waiting_ready")"
    read _ < "$SYNC_FIFO"
    log_info "$(_ "rollback.ready_received" "$SYNC_FIFO")"
    [[ -n "$SYNC_FIFO" ]] && printf '%s\0' "$SYNC_FIFO" | sys::file::delete
}

# @type:        Orchestrator
# @description: Обрабатывает сигнал SIGUSR1 и останавливает модуль при откате
# @stdin:       нет
# @stdout:      нет
# @exit_code:   3 завершение через откат
common::rollback::stop_script_by_rollback_timer() {
    log_info "$(_ "common.helpers.rollback.stop_received")"
    printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
    exit 3
}

# @type:        Orchestrator
# @description: Обрабатывает сигнал EXIT и выполняет финализацию
# @stdin:       нет
# @stdout:      нет
# @exit_code:   $? сохраняет код возврата предыдущей команды
common::exit::actions() {
    local rc=$?
    log_info "$(_ "common.exit_received" "$rc")"
    [[ -n "$WATCHDOG_FIFO" ]] && printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
    log_stop
    exit $rc
}

# @type:        Orchestrator
# @description: Обрабатывает сигнал SIGINT прерывания пользователем
# @stdin:       нет
# @stdout:      нет
# @exit_code:   130 прерывание пользователем (SIGINT)
#               $? другие коды
common::int::actions() {
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        rc=130
        new_line
    fi
    log_info "$(_ "common.int_received" "$rc")"
    exit $rc
}

# @type:        Sink
# @description: Обрабатывает ошибки pipe и возвращает код завершения
# @params:      rc_pipe Массив кодов возврата из pipe (array)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   2 отмена пользователем
#               130 прерывание пользователем (SIGINT)
#               1 критическая ошибка
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
# @description: Получает метод аутентификации текущего пользователя
# @stdin:       нет
# @stdout:      connection_type\0 (key/pass/timeout/n/a)
# @exit_code:   0 всегда успешно
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
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 сервис успешно перезапущен
#               1 ошибка конфигурации sshd
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
# @stdin:       port\0 (опционально)
# @stdout:      port\0 (опционально)
# @exit_code:   0 всегда успешно
ufw::rule::reset_and_pass() {
    local port=""

    # || true: Гасим код 1 если [[ ! -t 0 ]] возвращает false (stdin не подключен)
    [[ ! -t 0 ]] && read -r -d '' port || true

    ufw::rule::delete_all_bsss

    # || true: Гасим код 1 если [[ -n "$port" ]] возвращает false (port пустой)
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}

# @type:        Sink
# @description: Удаляет все правила UFW BSSS
# @stdin:       rule\0 (0..N)
# @stdout:      нет
# @exit_code:   0 всегда успешно
ufw::rule::delete_all_bsss() {
    local rule_args
    while IFS= read -r -d '' rule_args || break; do

        if printf '%s' "$rule_args" | xargs ufw --force delete >/dev/null 2>&1; then
            log_info "$(_ "common.helpers.ufw.rule.deleted" "$rule_args")"
        else
            log_warn "$(_ "common.helpers.ufw.rule.delete_error" "$rule_args")"
        fi
    done < <(ufw::rule::get_all_bsss)
}

# @type:        Source
# @description: Получает все правила UFW BSSS
# @stdin:       нет
# @stdout:      rule\0 (0..N)
# @exit_code:   0 всегда успешно
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
# @stdin:       нет
# @stdout:      rule\0 (0..N)
# @exit_code:   0 всегда успешно
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
# @stdin:       port\0 (0..N)
# @stdout:      нет
# @exit_code:   0 всегда успешно
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

# @type:        Validator
# @description: Проверяет, активен ли UFW
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 UFW активен
#               1 UFW неактивен или ошибка
ufw::status::is_active() {
    local res
    if res=$(ufw status 2>&1); then
        printf '%s' "$res" | grep -wq "active"
    else
        log_warn "$(_ "common.helpers.ufw.error_interrupt" "${res//$'\n'/ }")"
        ufw::status::force_disable
        return 1
    fi
}

# @type:        Orchestrator
# @description: Деактивирует UFW если он активен
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда успешно
ufw::status::force_disable() {
    if ufw::status::is_active; then
        ufw --force disable >/dev/null 2>&1
        log_info "$(_ "common.helpers.ufw.disabled")"
    fi
}

# @type:        Validator
# @description: Проверяет, существует ли бэкап файла настроек PING
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 бэкап существует (PING отключен)
#               1 бэкап не существует (PING не отключен)
ufw::ping::is_configured() {
    [[ -f "$UFW_BEFORE_RULES_BACKUP" ]]
}

# @type:        Orchestrator
# @description: Восстанавливает файл before.rules из бэкапа и удаляет бэкап
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно восстановлено
#               $? код ошибки cp или rm
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
# @description: Создает FIFO для подтверждения готовности rollback
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
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
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда успешно
ufw::log::status() {
    ufw::status::is_active && \
    log_info "$(_ "ufw.status.enabled")" || \
    log_info "$(_ "ufw.status.disabled")"
}

# @type:        Sink
# @description: Логирует состояние PING
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда успешно
ufw::log::ping_status() {
    ufw::ping::is_configured && \
    log_info "$(_ "ufw.status.ping_blocked")" || \
    log_info "$(_ "ufw.status.ping_allowed")"
}

# @type:        Orchestrator
# @description: Отображает статусы UFW
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда успешно
ufw::orchestrator::log_statuses() {
    ufw::log::status
    ufw::log::rules
    ufw::log::ping_status
}

# @type:        Orchestrator
# @description: Выводит активные правила UFW
# @params:      pattern Шаблон для фильтрации конфигурации (string\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда успешно
common::log::current_config() {
    local pattern="$1"
    local line

    log_info "$(_ "permissions.check.current_ssh_config")"

    while IFS= read -r line; do
        log_info_simple_tab "$(_ "no_translate" "$line")"
    # || true: sshd -T или grep могут не сработать в некоторых случаях
    done < <(sshd -T 2>/dev/null | grep -Ei "$pattern" | sort || true)
}

# @type:        Orchestrator
# @description: Инициирует немедленный откат через SIGUSR2 и ожидает завершения watchdog
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - откат выполнен, процесс заблокирован
ssh::orchestrator::trigger_immediate_rollback() {
    # || true: WATCHDOG_PID может уже не существовать или завершиться во время kill/wait
    log_info "$(_ "rollback.signal_usr2_sent")"
    kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
    # || true: Процесс может уже завершиться к моменту вызова wait
    wait "$WATCHDOG_PID" 2>/dev/null || true
    while true; do sleep 1; done
}

# @type:        Orchestrator
# @description: Блокирующая проверка поднятия SSH порта после изменения
# @params:      port Порт для проверки (string\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 порт успешно поднят
#               1 порт не поднялся в течение таймаута
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

permissions::check::current_user() {
    local root_id auth_id auth_name current_conn_type err=0
    root_id=$(id -u root)
    auth_id=$(id -u "$(logname)")
    auth_name="$(logname)"
    current_conn_type=$(sys::user::get_auth_method | tr -d '\0')
    

    log_info "$(_ "permissions.info.session_owner_conn_type" "$(logname)" "$current_conn_type")"
    permissions::orchestrator::log_statuses

    if [[ "$current_conn_type" == "pass" ]]; then
        log_attention "$(_ "permissions.attention.password_connection")"
        err=1
    fi

    if (( root_id == auth_id )); then
        log_attention "$(_ "permissions.warn.root_auth" "$auth_name|id:$auth_id|auth:$current_conn_type")"
        err=1
    fi

    if (( err == 1 )); then
        return 4
    fi
}

permissions::orchestrator::log_statuses() {
    common::log::current_config "^pubkeyauthentication|^passwordauthentication|^permitrootlogin"
    permissions::log::bsss_configs
    permissions::log::other_configs
}
