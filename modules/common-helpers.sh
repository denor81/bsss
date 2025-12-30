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
# @stdin:       Ничего.
# @stdout:      NUL-separated strings "path"
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
get_paths_by_mask() {
    local dir=${1:-.}
    local mask=${2:-*}

    ( shopt -s nullglob; printf '%s\0' "${dir%/}"/$mask )
}

# @type:        Filter
# @description: Возвращает строку - путь с типом.
# @params:      нет.
# @stdin:       NUL-separated paths
# @stdout:      NUL-separated strings "path:type"
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
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
# @params:      Нет.
# @stdin:       Нет.
# @stdout:      NUL-separated strings "port"
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
get_ssh_ports() {
    ss -Hltnp | awk '
        /"sshd"/ {
            match($4, /:[0-9]+$/, m);
            port = substr(m[0], 2)
            print port
        }
    ' | sort -nu | tr '\n' '\0'
}

# @type:        Validator
# @description: Проверяет возможность определения активных портов.
# @params:      Использует get_ssh_ports.
#   strict_mode [optional] If 1 - return 1 (default 0).
# @stdin:       Не используется.
# @stdout:      Ничего.
# @stderr:      Диагностические сообщения (log_info, log_error).
# @exit_code:   0 — порты определены, 1 — порты не определены (выполнение не возможно).
validate_ssh_ports() {
    local strict_mode=${1:-0}

    local active_ports=""
    active_ports=$(get_ssh_ports | tr '\0' ',' | sed 's/,$//')

    if [[ -z "$active_ports" ]]; then
        log_error "Активные порты не определены [ss -ltnp]"
        (( strict_mode == 1 )) && return 1
    else
        log_info "Активные SSH порты [ss -ltnp]: ${active_ports}"
    fi

}