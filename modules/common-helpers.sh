#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# @stdout:      # x 80
draw_border() {
    printf '%.0s#' {1..80} >&2; echo >&2
}

# @type:        Source
# @description: Получает список путей через нулевой разделитель.
# @params:
#   dir         [optional] Directory to search in (default: current directory).
#   mask        [optional] Glob pattern (default: "*").
# @stdin:       нет
# @stdout:      path\0 (0..N)
# @stderr:      нет
# @exit_code:   0 - всегда.
get_paths_by_mask() {
    local dir=${1:-.}
    local mask=${2:-*}

    (
        shopt -s nullglob
        local files=("${dir%/}/"$mask)
        (( ${#files[@]} > 0 )) && printf '%s\0' "${files[@]}"
    )
}

# @type:        Filter
# @description: Возвращает строку - путь с типом.
# @params:      нет.
# @stdin:       NUL-separated paths
# @stdout:      NUL-separated strings "path:type"
# @stderr:      Ничего.
# @exit_code:   0 - всегда.
get_modules_paths_w_type () {
    xargs -r0 awk -F ':[[:space:]]' '
        BEGIN { IGNORECASE=1; ORS="\0" }
        /^# MODULE_TYPE:/ {
            print FILENAME "<:>" $2
            nextfile  
        }
    '
}

# @type:        Filter
# @description: Возвращает отфильтрованные по типу пути к модулям.
# @params:      
#   type        Module type.
# @stdin:       NUL-separated strings "path:type"
# @stdout:      NUL-separated strings "path"
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
get_modules_by_type () {
    awk -v type="$1" -v RS='\0' -F'<:>' '
        type == $2 { printf "%s\0", $1 }
    '
}

# @type:        Source
# @description: Получает активные SSH порты из ss.
# @params:      нет
# @stdin:       нет
# @stdout:      "port\0"
# @stderr:      нет
# @exit_code:   0 — всегда.
ssh::get_ports_from_ss() {
    ss -Hltnp | awk '
        BEGIN { ORS="\0" }
        /"sshd"/ {
            if (match($4, /:[0-9]+$/, m)) {
                print substr(m[0], 2)
            }
        }
    ' | sort -zu
}

# @type:        Source
# @description: Получает первый порт из path
# @params:      нет
# @stdin:       "path\0"
# @stdout:      "port\0"
# @stderr:      нет
# @exit_code:   0 - всегда
ssh::get_first_port_from_path() {
    xargs -r0 awk '
        BEGIN { IGNORECASE=1; ORS="\0"; }
        /^\s*Port\s+/ {
            print $2
            exit
        }
    '
}

# @type:        Validator
# @description: Проверяет возможность определения активных портов.
# @params:      Использует ssh::get_ports_from_ss.
#   strict_mode [optional] Строгий режим вызывающий ошибку 1 при не доступности портов
#               строгий режим выполняется при старте скрипта, что бы точно быть уверенным,
#               что ss команда выполянется и порты определяются
# @stdin:       Не используется.
# @stdout:      Ничего.
# @stderr:      Диагностические сообщения (log_info, log_error).
# @exit_code:   0 — порты определены, 1 — порты не определены (выполнение не возможно).
ssh::log_active_ports_ss() {
    local strict_mode=${1:-0}

    local active_ports=""
    active_ports=$(ssh::get_ports_from_ss | tr '\0' ',' | sed 's/,$//')

    if [[ -z "$active_ports" ]]; then
        log_error "Активные порты не определены [ss -ltnp]"
        (( strict_mode == 1 )) && return 1
    else
        log_info "Активные SSH порты [ss -ltnp]: ${active_ports}"
    fi

}