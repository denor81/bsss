#!/usr/bin/env bash
# local-runner.sh
# Локальный загрузчик для запуска основного скрипта с конфигурацией
# Usage: ./local-runner.sh [options] [--uninstall]

set -Eeuo pipefail

# Константы
# shellcheck disable=SC2155
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly UNINSTALL_PATHS="${MAIN_DIR_PATH}/.uninstall_paths"
readonly RUN_PATH="${MAIN_DIR_PATH}/bsss-main.sh"
readonly ALLOWED_PARAMS="hu"
readonly UTIL_NAME="bsss"

UNINSTALL_FLAG=0
HELP_FLAG=0
INCORRECT_PARAM_FLAG=0
ERR_PARAM_PARSE_FLAG=0
RUN=0

readonly SUCCESS=0
readonly ERR_PARAM_PARSE=1
readonly ERR_UNINSTALL=2
readonly ERR_RUN_MAIN_SCRIPT=3

readonly SYMBOL_SUCCESS="[V]"
readonly SYMBOL_QUESTION="[?]"
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[X]"

# Функции логирования
log_success() { echo "$SYMBOL_SUCCESS $1"; }
log_error() { echo "$SYMBOL_ERROR $1" >&2; }
log_info() { echo "$SYMBOL_INFO $1"; }

# Функция удаления установленных файлов и директорий
run_uninstall() {
    # Запрашиваем подтверждение удаления
    read -p "$SYMBOL_QUESTION Выбрано удаление $UTIL_NAME - подтвердите - y/n [n]: " -r confirmation
    confirmation=${confirmation:-n}
    
    if [[ ! ${confirmation,,} =~ ^[y]$ ]]; then
        log_info "Удаление отменено"
        return $SUCCESS
    fi
    
    # Проверяем наличие файла с путями для удаления
    if [[ ! -f "$UNINSTALL_PATHS" ]]; then
        log_error "Файл с путями для удаления не найден: $UNINSTALL_PATHS"
        return $ERR_UNINSTALL
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
            log_info "Удалено: $path"
        else
            log_info "Путь не существует, пропускаю: $path"
        fi
    done < "$UNINSTALL_PATHS"
    
    log_success "Удаление завершено успешно"
    return $SUCCESS
}

# Запуск без параметров
if [ "$#" -eq 0 ]; then
    RUN=1
fi

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
    
    # Запускаем основной скрипт через exec, заменяя текущий процесс
    if [[ $RUN -eq 1 ]]; then
        if [[ -f "$RUN_PATH" ]]; then
            exec bash "$RUN_PATH" "$@"
        else
            log_error "Основной скрипт не найден: $RUN_PATH"
            return $ERR_RUN_MAIN_SCRIPT
        fi
    fi
}

main "$@"