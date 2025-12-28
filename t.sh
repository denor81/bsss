#!/usr/bin/env bash

source "./lib/vars.conf"

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

_get_paths_by_mask_updated() {
    local dir=${1:-.}
    local mask=${2:-*}
}

_get_all_modules_with_types() {
    local raw_paths=""
    local -a available_paths=()

    raw_paths=$(_get_paths_by_mask "${MAIN_DIR_PATH}/modules" "$MODULES_MASK") || return 1

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

get_modules_w_types() {
    
}

get_modules_w_types