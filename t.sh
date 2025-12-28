#!/usr/bin/env bash

source "./lib/vars.conf"
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"


_get_paths_by_mask() {
    local dir="$1"
    local mask="$2"

    local -a paths

    [[ ! -d "$dir" ]] && { log_error "Директория $dir не найдена"; return 1; }

    # Собираем файлы в массив (Bash сам их отсортирует)
    shopt -s nullglob

    # Важно: переменная $mask НЕ должна быть в кавычках здесь, 
    # чтобы Bash мог её развернуть в список файлов.
    paths=("${dir%/}/"$mask)
    shopt -u nullglob

    if (( ${#paths[@]} > 0 )); then
        printf '%s\n' "${paths[@]}"
    fi
}

# Return: path{\0}
_get_paths_by_mask_updated() {
    local dir=${1:-.}
    local mask=${2:-*}

    ( shopt -s nullglob; printf '%s\0' "${dir%/}"/$mask )
}

_get_all_modules_with_types() {
    local raw_paths=""
    local -a available_paths=()

    raw_paths=$(_get_paths_by_mask_updated "${MAIN_DIR_PATH%/}/$MODULES_DIR" "$MODULES_MASK") || return 1

    if [[ -n "$raw_paths" ]]; then
        mapfile -t available_paths < <(printf '%s' "$raw_paths")
    fi

    if (( ${#available_paths[@]} == 0 )); then
        log_error "Модули не найдены, выполнение скрипта не возможно"
        return 1
    else
        awk -F': ' 'BEGIN { OFS="\t" } /^# MODULE_TYPE:/ { print FILENAME, $2; nextfile }' "${available_paths[@]}"
    fi
}

# Return: path{:}type{\0}
_get_all_modules_with_types_updated () {
    _get_paths_by_mask_updated "${MAIN_DIR_PATH%/}/$MODULES_DIR" "$MODULES_MASK" \
    | xargs -r0 grep -HEi '(^|\s*)#\s*MODULE_TYPE:\s+' 2>/dev/null \
    | sed -E 's/:\s*#\s*MODULE_TYPE\s*:\s*/:/I' \
    | tr '\n' '\0'
}

_get_all_modules_with_types_awk () {
    xargs -r0 awk -F ':[[:space:]]' '
        BEGIN { IGNORECASE=1 }
        /^# MODULE_TYPE:/ {
            print FILENAME ":" $2
            nextfile  
        }
    ' | tr '\n' '\0'
}

get_modules_w_types() {
    # _get_all_modules_with_types_updated "$SSH_CONFIGD_DIR" "$SSH_CONFIG_FILE_MASK"
    # _get_all_modules_with_types_updated
    _get_paths_by_mask_updated "${MAIN_DIR_PATH%/}/$MODULES_DIR" "$MODULES_MASK" | _get_all_modules_with_types_awk
}

get_modules_w_types