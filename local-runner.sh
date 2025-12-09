#!/usr/bin/env bash
# local-runner.sh
# Локальный загрузчик для запуска основного скрипта с конфигурацией
# Usage: ./local-runner.sh [options] [--uninstall]

set -Eeuo pipefail

# Константы
readonly UTIL_NAME="bsss"
# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly UNINSTALL_PATHS="${THIS_DIR_PATH}/.uninstall_paths"
readonly RUN_PATH="${THIS_DIR_PATH}/bsss-main.sh"
readonly ALLOWED_PARAMS="hu"
# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly CURRENT_MODULE_NAME="$(basename "$0")"

UNINSTALL_FLAG=0
HELP_FLAG=0
RUN=0

INCORRECT_PARAM_FLAG=0
ERR_PARAM_PARSE_FLAG=0

readonly SUCCESS=0
readonly ERR_PARAM_PARSE=1
readonly ERR_UNINSTALL=2
readonly ERR_RUN_MAIN_SCRIPT=3

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/lib/logging.sh"

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

# Функция удаления установленных файлов и директорий
run_uninstall() {
    # Запрашиваем подтверждение удаления
    read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] Выбрано удаление $UTIL_NAME - подтвердите - y/n [n]: " -r confirmation
    confirmation=${confirmation:-n}
    
    if [[ ! ${confirmation,,} =~ ^[y]$ ]]; then
        log_info "Удаление отменено"
        return "$SUCCESS"
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
    return "$SUCCESS"
}

# Основная функция
main() {
    if [[ $UNINSTALL_FLAG -eq 1 ]]; then
        run_uninstall
        return $?
    fi
    if [[ $HELP_FLAG -eq 1 ]]; then
        log_info "Доступны короткие параметры $ALLOWED_PARAMS, [-h помощь] [-u удаление]"
        return "$SUCCESS"
    fi
    if [[ $INCORRECT_PARAM_FLAG -eq 1 || $ERR_PARAM_PARSE_FLAG -eq 1 ]]; then
        log_info "Некорректный параметр, доступны короткие параметры $ALLOWED_PARAMS, например -h для вызова помощи"
        return $ERR_PARAM_PARSE
    fi
    
    # Запускаем основной скрипт через exec, заменяя текущий процесс
    if [[ $RUN -eq 1 ]]; then
        if [[ -f "$RUN_PATH" ]]; then
            exec bash "$RUN_PATH"
            return $?
        else
            log_error "Основной скрипт не найден: $RUN_PATH"
            return $ERR_RUN_MAIN_SCRIPT
        fi
    fi
}

main
log_success "Завершен"
