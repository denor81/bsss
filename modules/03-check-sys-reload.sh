#!/usr/bin/env bash
# 03-check-sys-reload.sh
# Третий модуль системы
# Проверяет необходимость перезагрузки системы
# MODULE_TYPE: check-only

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly REBOOT_REQUIRED_FILE="/var/run/reboot-required"

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/../lib/logging.sh"

# TESTED: tests/test_check_sys_reload.sh
check() {
    local reboot_file=${1:-$REBOOT_REQUIRED_FILE}
    local status
    local message
    local symbol

    if [[ -f "$reboot_file" ]]; then
        status=1
        message="Требуется перезагрузка системы"
        symbol="$SYMBOL_ERROR"
    else
        status=0
        message="Перезагрузка не требуется"
        symbol="$SYMBOL_SUCCESS"
    fi
    
    # Вывод в Key-Value формате для парсинга через eval
    echo "message=\"$(printf '%s' "$message" | base64)\""
    echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
    echo "status=$status"
}

main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
