#!/usr/bin/env bash
# MODULE_TYPE: helper

set -Eeuo pipefail

# Получает список всех файлов по маске
_get_files_paths_by_mask() {
    local dir="$1"
    local mask="$2"

    # Проверка директории
    [[ ! -d "$dir" ]] && { log_error "Директория $dir не найдена"; return 1; }

    # Собираем файлы в массив (Bash сам их отсортирует)
    shopt -s nullglob

    # Важно: переменная $mask НЕ должна быть в кавычках здесь, 
    # чтобы Bash мог её развернуть в список файлов.
    local files=("$dir"/$mask)
    shopt -u nullglob

    if (( ${#files[@]} > 0 )); then
        printf '%s\n' "${files[@]}"
    else
        log_error "Файлы по маске $mask в директории $dir не найдены";
    fi
}
