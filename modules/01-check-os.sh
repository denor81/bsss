#!/usr/bin/env bash
# Проверяет операционную систему
# MODULE_TYPE: check

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"

check() {
    if [[ -f "$OS_RELEASE_FILE_PATH" ]]; then
        source "$OS_RELEASE_FILE_PATH"
        
        if [[ "$ID" != "$ALLOWED_SYS" ]]; then
            log_error "Система ${ID^} не поддерживается"
            return 1
        else
            log_info "Система ${ID^} поддерживается"
        fi
    fi
}

main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi