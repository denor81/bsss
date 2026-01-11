#!/usr/bin/env bash
# Проверяет необходимость перезагрузки системы
# MODULE_TYPE: check

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"

# @type:        Orchestrator
# @description: Проверяет необходимость перезагрузки системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - перезагрузка не требуется
#               1 - необходима перезагрузка
check() {
    if [[ -f "$REBOOT_REQUIRED_FILE_PATH" ]]; then
        log_error "Система нуждается в перезагрузке $REBOOT_REQUIRED_FILE_PATH"
        return 1
    else
        log_info "Перезагрузка не требуется"
    fi
}

main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
