#!/usr/bin/env bash
# module-03.sh
# Третий модуль системы
# Проверяет необходимость перезагрузки системы
# Usage: ./03-check-sys-reload.sh [-c]
#   -c  Экспресс-анализ с выводом в Key-Value формате

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
# shellcheck disable=SC2155
readonly SCRIPT_NAME=$(basename "$0")
# shellcheck disable=SC2034
readonly CURRENT_MODULE_NAME="$SCRIPT_NAME"
readonly REBOOT_REQUIRED_FILE="/var/run/reboot-required"
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

# Парсер вывода в Key-Value формате
_parse_output() {
    local output="$1"
    local key="$2"
    echo "$output" | grep "^${key}=" | cut -d'=' -f2-
}

# ========== ОСНОВНЫЕ ФУНКЦИИ МОДУЛЯ ==========

check() {
    local status=0
    local message="Перезагрузка не требуется"
    local details="Система работает в штатном режиме"
    
    if [[ -f "$REBOOT_REQUIRED_FILE" ]]; then
        status=1
        message="Требуется перезагрузка системы"
        details="Обнаружен файл $REBOOT_REQUIRED_FILE"
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

run() {
    log_info "ЗАПУСК МОДУЛЯ $SCRIPT_NAME В СТАНДАРТНОМ РЕЖИМЕ"
    
    if [[ -f "$REBOOT_REQUIRED_FILE" ]]; then
        log_error "Требуется перезагрузка системы. Перезагрузитесь командой reboot. Обнаружен файл $REBOOT_REQUIRED_FILE"
        return 1
    else
        log_info "Перезагрузка не требуется"
        return 0
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
