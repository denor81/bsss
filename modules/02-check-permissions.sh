#!/usr/bin/env bash
# 02-check-permissions.sh
# Второй модуль системы
# Проверяет права доступа
# MODULE_TYPE: check-only

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/../lib/logging.sh"

# TESTED: tests/test_check-permissions_check.sh
check() {
    local euid=${1:-$EUID}  # Effective user ID, defaults to current EUID
    local sudo_check_command=${2:-"sudo -n true 2>/dev/null"}  # Command to check sudo access
    local status
    local message
    local symbol

    if [[ "$euid" -eq 0 ]]; then
        status=0
        message="Имеются права root"
        symbol="$SYMBOL_SUCCESS"
    elif eval "$sudo_check_command"; then
        status=0
        message="Имеются права через sudo"
        symbol="$SYMBOL_SUCCESS"
    else
        status=1
        message="Требуются права root или членство в группе sudo"
        symbol="$SYMBOL_ERROR"
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