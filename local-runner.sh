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

# Парсинг параметров запуска с использованием getopts
_parse_params() {
    # Всегда используем дефолтный ALLOWED_PARAMS
    local allowed_params="${1:-$ALLOWED_PARAMS}"
    shift
    
    while getopts ":$allowed_params" opt "$@"; do
        case "${opt}" in
            h)  ACTION="help" ;;
            u)  ACTION="uninstall" ;;
            \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params" ;;
            :)  log_error "Параметр -$OPTARG требует значение" ;;
        esac
    done
}

_check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
        return 1
    fi
}

_show_help() {
    log_info "Доступны короткие параметры $ALLOWED_PARAMS $ALLOWED_PARAMS_HELP"
}

_run_default() {
    exec bash "$MAIN_DIR_PATH/$MAIN_FILE"
}

# Основная функция
main() {
    _check_permissions
    _parse_params "$ALLOWED_PARAMS" "$@"

    case "$ACTION" in
        help)      _show_help ;;
        uninstall) _run_uninstall ;;
        *)         _run_default ;;
    esac
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi