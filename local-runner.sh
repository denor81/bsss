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

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/lib/logging.sh"

# Подключаем библиотеку функций удаления
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/lib/uninstall_functions.sh"

# log_info "Запуск"

# Парсинг параметров запуска с использованием getopts
# TESTED: tests/test_local-runner_parse_params.sh
_parse_params() {
    # Всегда используем дефолтный ALLOWED_PARAMS
    local allowed_params="${1:-$ALLOWED_PARAMS}"
    shift

    # Сбрасываем OPTIND
    OPTIND=1
    
    while getopts ":$allowed_params" opt "$@"; do
        case "${opt}" in
            h)  HELP_FLAG=1 ;;
            u)  UNINSTALL_FLAG=1 ;;
            \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params" ;;
            :)  log_error "Параметр -$OPTARG требует значение" ;;
        esac
    done
}

# Основная функция
main() {
    _parse_params "$ALLOWED_PARAMS" "$@"
    if [[ $UNINSTALL_FLAG -eq 1 ]]; then
        # Вызываем адаптированную для тестирования версию функции с параметрами по умолчанию
        _run_uninstall_testable "$UNINSTALL_PATHS" "$UTIL_NAME" "$CURRENT_MODULE_NAME" "false"
    fi
    if [[ $HELP_FLAG -eq 1 ]]; then
        log_info "Доступны короткие параметры $ALLOWED_PARAMS, [-h помощь] [-u удаление]"
        return 0
    fi
    
    # Запускаем основной скрипт через exec, заменяя текущий процесс
    if [[ "$#" -eq 0 ]]; then
        if [[ -f "$RUN_PATH" ]]; then
            exec bash "$RUN_PATH"
        else
            log_error "Основной скрипт не найден: $RUN_PATH"
            return 1
        fi
    else
        log_error "Ошибка запуска"
    fi
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi