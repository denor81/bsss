#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# Получает список всех файлов по маске
# Вернет либо пути либо ничего
_get_paths_by_mask() {
    local dir=${1:-.}
    local mask=${2:-*}

    ( shopt -s nullglob; printf '%s\0' "${dir%/}"/$mask )
}
}

_delete_paths() {
    local raw_paths="$1"
    local path
    local -a paths=()

    mapfile -t paths < <(printf '%s' "$raw_paths")

    for path in "${paths[@]}"; do
        if rm -rf "$path"; then
            log_info "Удалено: $path"
        fi
    done
}