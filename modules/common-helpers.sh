#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# @type:        Source
# @description: Получает список путей через нулевой разделитель
# @params:
#   dir         [optional] Directory to search in (default: current directory)
#   mask        [optional] Glob pattern (default: "*")
# @stdin:       нет
# @stdout:      path\0 (0..N)
# @exit_code:   0 - всегда
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
# @description: Возвращает строку - путь с типом
# @params:      нет
# @stdin:       path\0 (0..N)
# @stdout:      path:type\0 (0..N)
# @exit_code:   0 - всегда
sys::module::get_paths_w_type () {
    xargs -r0 awk -F ':[[:space:]]+' '
        BEGIN { IGNORECASE=1; ORS="\0" }
        /^# MODULE_TYPE:/ {
            print FILENAME "<:>" $2
            nextfile
        }
    '
}

# @type:        Filter
# @description: Возвращает отфильтрованные по типу пути к модулям
# @params:
#   type        Module type
# @stdin:       path:type\0 (0..N)
# @stdout:      path\0 (0..N)
# @exit_code:   0 - всегда
sys::module::get_by_type () {
    awk -v type="$1" -v RS='\0' -F'<:>' '
        type == $2 { printf "%s\0", $1 }
    '
}

# @type:        Filter
# @description: Удаляет указанные файлы и директории
# @params:      нет
# @stdin:       path\0 (0..N)
# @stdout:      нет
# @exit_code:   0 - всегда
sys::file::delete() {
    while IFS= read -r -d '' path || break; do
        local resp
        resp=$(rm -rfv -- "$path" ) || return
        log_info "Удалено: $resp"
    done
}

# @type:        Source
# @description: Получает активные SSH порты из ss
# @params:      нет
# @stdin:       нет
# @stdout:      port\0 (0..N)
# @exit_code:   0 - всегда
ssh::port::get_from_ss() {
    ss -Hltnp | awk '
        BEGIN { ORS="\0" }
        /"sshd"/ {
            if (match($4, /:[0-9]+$/, m)) {
                print substr(m[0], 2)
            }
        }
    ' | sort -zu
}

# @type:        Filter
# @description: Получает первый порт из path
# @params:      нет
# @stdin:       path\0
# @stdout:      port\0
# @exit_code:   0 - всегда
ssh::port::get_first_from_path() {
    xargs -r0 awk '
        BEGIN { IGNORECASE=1; ORS="\0"; }
        /^\s*Port\s+/ {
            print $2
            exit
        }
    '
}

# @type:        Orchestrator
# @description: Проверяет возможность определения активных портов
# @params:
#   strict_mode [optional] Строгий режим вызывающий ошибку 1 при недоступности портов
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - порты определены
#               1 - порты не определены
ssh::port::log_active_from_ss() {
    local strict_mode=${1:-0}

    local active_ports=""
    active_ports=$(ssh::port::get_from_ss | tr '\0' ',' | sed 's/,$//')

    if [[ -z "$active_ports" ]]; then
        log_error "Нет активных SSH портов [ss -ltnp]"
        (( strict_mode == 1 )) && return 1
    else
        log_info "Есть активные SSH порты [ss -ltnp]: ${active_ports}"
    fi

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
            log_info "Есть правила UFW [ufw show added]"
            log_bold_info "Правила UFW синхронизированы с настройками ${UTIL_NAME^^} для SSH порта"
            log_bold_info "Удаляя правила SSH, также будут удалены связанные правила UFW"
            found=$((found + 1))
        fi
        log_info_simple_tab "$rule"

    done < <(ufw::rule::get_all)

    if (( found == 0 )); then
        log_info "Нет правил UFW [ufw show added]"
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
    [[ ! -t 0 ]] && IFS= read -r -d '' port || true
    
    ufw::rule::delete_all_bsss

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}

# @type:        Orchestrator
# @description: Удаляет все правила UFW BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::rule::delete_all_bsss() {
    # local found_any=0

    local rule_args
    while IFS= read -r -d '' rule_args || break; do
        # found_any=1

        if printf '%s' "$rule_args" | xargs ufw --force delete >/dev/null 2>&1; then
            log_info "Удалено правило UFW: ufw --force delete $rule_args"
        else
            log_error "Ошибка при удалении правила UFW: ufw --force delete $rule_args"
        fi
    done < <(ufw::rule::get_all_bsss)

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
ufw::rule::get_all_bsss() {
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
ufw::rule::get_all() {
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
ufw::rule::add_bsss() {
    local port
    while read -r -d '' port; do
        if ufw allow "${port}"/tcp comment "$BSSS_MARKER_COMMENT" >/dev/null 2>&1; then
            log_info "Создано правило UFW: [ufw allow ${port}/tcp comment $BSSS_MARKER_COMMENT]"
        else
            log_info "Ошибка при добавлении правила UFW: [ufw allow ${port}/tcp comment $BSSS_MARKER_COMMENT]"
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
ufw::rule::is_active() {
    ufw status | grep -q "^Status: active"
}

# @type:        Filter
# @description: Деактивирует UFW (пропускает если уже деактивирован)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::rule::force_disable() {
    if ! ufw::rule::is_active; then
        log_info "UFW: Уже деактивирован, действие пропущено"
    else
        ufw --force disable >/dev/null 2>&1
        log_info "UFW: Полностью деактивирован [ufw --force disable]"
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
    local rollback_module="${PROJECT_ROOT}/${UTILS_DIR}/$ROLLBACK_MODULE_NAME"

    # Запускаем "Сторожа" отвязано от терминала
    # Передаем PID основного скрипта ($$) первым аргументом
    ROLLBACK_TYPE="$1" nohup bash "$rollback_module" "$$" "$WATCHDOG_FIFO" >/dev/null 2>&1 &
    printf '%s' "$!" # Возвращаем PID для оркестратора
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
    kill -USR1 "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
    log_info "Rollback отключен [PID: $WATCHDOG_PID]"
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
    log::new_line
    log_info "Создан FIFO: $WATCHDOG_FIFO"
    cat "$WATCHDOG_FIFO" >&2 &
}
