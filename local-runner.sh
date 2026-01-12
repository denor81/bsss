#!/usr/bin/env bash
# local-runner.sh
# Локальный загрузчик для запуска основного скрипта с конфигурацией
# Usage: ./local-runner.sh [options] [-h]

set -Eeuo pipefail

# Константы
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly MAIN_FILE="bsss-main.sh"
readonly ALLOWED_PARAMS="hu"
readonly ALLOWED_PARAMS_HELP="[-h помощь | -u удаление]"
readonly CURRENT_MODULE_NAME="$(basename "$0")" # Used in logging

ACTION=""

source "${MAIN_DIR_PATH}/lib/vars.conf"
source "${MAIN_DIR_PATH}/lib/logging.sh"
source "${MAIN_DIR_PATH}/lib/uninstall_functions.sh"

# @type:        Filter
# @description: Парсинг параметров запуска с использованием getopts
# @params:
#   allowed_params [optional] Разрешенные параметры (default: $ALLOWED_PARAMS)
#   @            Остальные параметры для парсинга
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - некорректный параметр
parse_params() {
    # Всегда используем дефолтный ALLOWED_PARAMS
    local allowed_params="${1:-$ALLOWED_PARAMS}"
    shift
    
    while getopts ":$allowed_params" opt "$@"; do
        case "${opt}" in
            h)  ACTION="help" ;;
            u)  ACTION="uninstall" ;;
            \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params"; return 1 ;;
            :)  log_error "Параметр -$OPTARG требует значение"; return 1 ;;
        esac
    done
}

# @type:        Filter
# @description: Проверяет права доступа для запуска скрипта
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - права root есть
#               1 - недостаточно прав
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
        return 1
    fi
}

# @type:        Sink
# @description: Выводит справочную информацию
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
show_help() {
    log_info "Доступны короткие параметры $ALLOWED_PARAMS $ALLOWED_PARAMS_HELP"
}

# @type:        Orchestrator
# @description: Запускает основной скрипт
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   не возвращается (exec)
run_default() {
    exec bash "${MAIN_DIR_PATH%/}/$MAIN_FILE"
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      @ - параметры командной строки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка проверки прав или параметров
main() {
    check_permissions
    parse_params "$ALLOWED_PARAMS" "$@"

    case "$ACTION" in
        help)      show_help ;;
        uninstall) run_uninstall ;;
        *)         run_default ;;
    esac
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi