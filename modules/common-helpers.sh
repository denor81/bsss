#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# Получает список всех файлов по маске
# Вернет либо пути либо ничего
_get_paths_by_mask() {
    local dir="$1"
    local mask="$2"

    local -a paths

    # Проверка директории
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