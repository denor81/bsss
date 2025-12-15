#!/usr/bin/env bash
# 01-check-os.sh
# Первый модуль системы
# Проверяет операционную систему
# MODULE_TYPE: check-only

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly OS_RELEASE_FILE="/etc/os-release"
readonly ALLOWED_SYS="ubuntu"

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/../lib/logging.sh"

# TESTED: tests/test_check-os_check.sh
check() {
    local os_release_file=${1:-$OS_RELEASE_FILE}
    local allowed_sys=${2:-$ALLOWED_SYS}
    local status
    local message
    local symbol

    # shellcheck disable=SC1090
    if [[ -f "$os_release_file" ]]; then
        source "$os_release_file"

        if [[ "$ID" != "$allowed_sys" ]]; then
            status=1
            message="$ID не поддерживается, поддерживается только ${allowed_sys^}"
            symbol="$SYMBOL_ERROR"
        else
            status=0
            message="Текущая система ${ID^} $VERSION_ID поддерживается"
            symbol="$SYMBOL_INFO"
        fi
    else
        status=1
        message="Файл $os_release_file не наден"
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