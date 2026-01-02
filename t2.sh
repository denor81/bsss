#!/usr/bin/env bash

source "./lib/vars.conf"
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"

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


get_paths_by_mask "$MODULES_DIR" "$MODULES_MASK" | get_modules_paths_w_type | get_modules_by_type "$MODULE_TYPE_MODIFY"