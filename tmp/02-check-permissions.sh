#!/usr/bin/env bash
# module-02.sh
# Второй модуль системы
# Проверяет права доступа
# Usage: ./02-check-permissions.sh [-c]
#   -c  Экспресс-анализ с выводом в Key-Value формате

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
# shellcheck disable=SC2155
readonly SCRIPT_NAME=$(basename "$0")
# shellcheck disable=SC2034
readonly CURRENT_MODULE_NAME="$SCRIPT_NAME"
readonly ALLOWED_PARAMS="c"

# Флаги режимов работы
CHECK_FLAG=0  # Режим экспресс-анализа

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}"/../lib/logging.sh

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========

# Парсер параметров командной строки
_parse_params() {
    local allowed_params="${1:-$ALLOWED_PARAMS}"
    shift

    # Сбрасываем OPTIND
    OPTIND=1
    
    while getopts ":$allowed_params" opt "$@"; do
        case "${opt}" in
            c)  CHECK_FLAG=1 ;;
            \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params" >&2 ;;
            :)  log_error "Параметр -$OPTARG требует значение" >&2 ;;
        esac
    done
}

# ========== ОСНОВНЫЕ ФУНКЦИИ МОДУЛЯ ==========

check() {
    local status=0
    local message="Права доступа: Root"
    local details="Имеются необходимые права для выполнения"
    
    if [[ "$EUID" -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            status=1
            message="Ошибка прав доступа"
            details="Требуются права root или членство в группе sudo"
        else
            status=0
            message="Права доступа: Sudo"
            details="Имеются необходимые права через sudo"
        fi
    fi
    
    # Вывод в Key-Value формате
    echo "module=$SCRIPT_NAME"
    echo "status=$status"
    echo "message=$message"
    echo "details=$details"
    
    # Возвращаем код в зависимости от статуса
    if [[ "$status" -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# ========== ОСНОВНАЯ ФУНКЦИЯ ==========

main() {
    # Если нет параметров, используем режим check по умолчанию
    if [[ "$#" -eq 0 ]]; then
        CHECK_FLAG=1
    fi
    
    # Парсим параметры
    _parse_params "$ALLOWED_PARAMS" "$@"
    
    # Выполняем в зависимости от режима
    if [[ "$CHECK_FLAG" -eq 1 ]]; then
        check
    else
        log_error "Не определен режим запуска. Используйте -c для проверки"
        return 1
    fi
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi