#!/usr/bin/env bash
# bsss-main.sh
# Основной скрипт для последовательного запуска модулей системы
# Usage: ./bsss-main.sh

set -Eeuo pipefail

# Константы
# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly MODULES_DIR="${THIS_DIR_PATH}/modules"
# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly CURRENT_MODULE_NAME="$(basename "$0")"


# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/lib/logging.sh"

# Получает список всех доступных модулей
get_available_modules() {
    if [[ -d "$MODULES_DIR" ]]; then
        # Ищем все исполняемые файлы, включая .sh и без расширения
        find "$MODULES_DIR" -type f \( -name "[0-9][0-9]*.sh" -o -executable \) | sort
    else
        log_error "Директория модулей не найдена: $MODULES_DIR"
        return 1
    fi
}

# Собирает экспресс-статус от всех модулей
collect_modules_status() {
    printf '%.0s#' {1..40}; echo
    while IFS= read -r module_path; do
        if [[ -n "$module_path" ]]; then
            out="$(bash "$module_path")"
            # Ожидаем от модуля message, symbol
            eval "$out"
            decoded_message=$(echo "$message" | base64 --decode)
            decoded_symbol=$(echo "$symbol" | base64 --decode)
            
            echo "# $decoded_symbol $(basename "$module_path"): $decoded_message"
        fi
    done <<< "$(get_available_modules)" || return 1
    printf '%.0s#' {1..40}; echo
}


# Основная функция
main() {
    # Сначала экспресс-анализ
    collect_modules_status
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
