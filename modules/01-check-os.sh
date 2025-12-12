#!/usr/bin/env bash
# module-01.sh
# Первый модуль системы
# Проверяет операционную систему
# Usage: ./01-check-os.sh

set -Eeuo pipefail

readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly OS_RELEASE_FILE="/etc/os-release"
readonly ALLOWED_SYS="ubuntu"

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/../lib/logging.sh"

check() {
    local status
    local message
    local symbol

    # shellcheck disable=SC1090
    if source "$OS_RELEASE_FILE" 2>/dev/null; then

        if [[ "$ID" != "$ALLOWED_SYS" ]]; then
            status=1
            message="$ID не поддерживается, поддерживается только ${ALLOWED_SYS^}"
            symbol="$SYMBOL_ERROR"
        else
            status=0
            message="Текущая система ${ID^} $VERSION_ID поддерживается"
            symbol="$SYMBOL_SUCCESS"
        fi

    fi
    
    # Вывод в Key-Value формате для парсинга через eval
    echo "message=\"$(printf '%s' "$message" | base64)\""
    echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
    
    # Возвращаем код в зависимости от статуса
    return $status
}

main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi