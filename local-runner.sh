#!/usr/bin/env bash
# local-runner.sh
# Локальный загрузчик для запуска основного скрипта с конфигурацией
# Usage: ./local-runner.sh [options] [--uninstall]

set -Eeuo pipefail

# Константы
# shellcheck disable=SC2155
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly UNINSTALL_PATHS="${MAIN_DIR_PATH}/.uninstall_paths"
readonly ALLOWED_PARAMS="hu"

UNINSTALL_FLAG=0
HELP_FLAG=0
INCORRECT_PARAM_FLAG=0
ERR_PARAM_PARSE_FLAG=0

readonly SUCCESS=0
readonly ERR_PARAM_PARSE=1
readonly ERR_UNINSTALL=2

# Функции логирования
log_success() { echo -e "[v] $1"; }
log_error() { echo -e "[x] $1" >&2; }
log_info() { echo -e "[*] $1"; }

# Функция удаления установленных файлов и директорий
run_uninstall() {
    # Проверяем наличие файла с путями для удаления
    if [[ ! -f "$UNINSTALL_PATHS" ]]; then
        log_error "Файл с путями для удаления не найден: $UNINSTALL_PATHS"
        return 1
    fi
    
    log_info "Начинаю удаление установленных файлов..."
    
    # Читаем файл построчно и удаляем каждый путь
    while IFS= read -r path; do
        # Проверяем существование пути или символической ссылки перед удалением
        if [[ -e "$path" || -L "$path" ]]; then
            log_info "Удаляю: $path"
            rm -rf "$path" || {
                log_error "Не удалось удалить: $path"
                return $ERR_UNINSTALL
            }
            log_success "Удалено: $path"
        else
            log_info "Путь не существует, пропускаю: $path"
        fi
    done < "$UNINSTALL_PATHS"
    
    log_success "Удаление завершено успешно"
    return $SUCCESS
}

# Парсинг параметров запуска с использованием getopts
while getopts ":$ALLOWED_PARAMS" opt; do
    case ${opt} in
        h)  HELP_FLAG=1 ;;
        u)  UNINSTALL_FLAG=1 ;;
        \?) INCORRECT_PARAM_FLAG=1 ;;
        :)  ERR_PARAM_PARSE_FLAG=1 ;;
    esac
done

# Основная функция
main() {
    if [[ $UNINSTALL_FLAG -eq 1 ]]; then
        run_uninstall "$@"
    fi
    if [[ $HELP_FLAG -eq 1 ]]; then
        log_info "Доступны короткие параметры $ALLOWED_PARAMS, например -h."
        return $SUCCESS
    fi
    if [[ $INCORRECT_PARAM_FLAG -eq 1 || $ERR_PARAM_PARSE_FLAG -eq 1 ]]; then
        log_info "Некорректный параметр, доступны короткие параметры $ALLOWED_PARAMS, например -h."
        return $ERR_PARAM_PARSE
    fi
}

main "$@"