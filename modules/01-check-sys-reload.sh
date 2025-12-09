#!/usr/bin/env bash
# module-01.sh
# Первый модуль системы
# Возвращает код успеха 0

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
# shellcheck disable=SC2155
readonly SCRIPT_NAME=$(basename "$0")
# shellcheck disable=SC2034
readonly CURRENT_MODULE_NAME="$SCRIPT_NAME"
readonly REBOOT_REQUIRED_FILE="/var/run/reboot-required"

CHECK_FLAG=1 # По умолчанию запускаем проверку

# Коды возврата
readonly SUCCESS=0
readonly ERR_RUN_FLAG=1
readonly ERR_SYS_REBOOT_REQUIRED=2

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}"/../lib/logging.sh

check() {
    log_info "ЗАПУСК МОДУЛЯ $SCRIPT_NAME В РЕЖИМЕ ПРОВЕРКИ"
    if [[ -f "$REBOOT_REQUIRED_FILE" ]]; then
        log_info "Требуется перезагрузки системы."
    else
        log_info "Перезагрузка не требутся"
    fi
    return "$SUCCESS"
}

run() {
    log_info "ЗАПУСК МОДУЛЯ $SCRIPT_NAME В СТАНДАРТНОМ РЕЖИМЕ"
    if [[ -f "$REBOOT_REQUIRED_FILE" ]]; then
        log_error "Требуется перезагрузки системы. Перезагрузитесь командой reboot. Обнаружен файл $REBOOT_REQUIRED_FILE"
        return "$ERR_SYS_REBOOT_REQUIRED"
    fi
    return "$SUCCESS"
}

main() {
    if [[ "$CHECK_FLAG" -eq 1 ]]; then
        check
        return $?
    elif [[ "$CHECK_FLAG" -eq 0 ]]; then
        run
        return $?
    else
        log_error "Не определен флаг запуска"
        return "$ERR_RUN_FLAG"
    fi
}

main 
