#!/usr/bin/env bash
# Проверяет необходимость перезагрузки системы
# MODULE_ORDER: 40
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"

# @type:        Orchestrator
# @description: Проверяет необходимость перезагрузки системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - перезагрузка не требуется
#               1 - необходима перезагрузка
check() {
    if [[ -f "$REBOOT_REQUIRED_FILE_PATH" ]]; then
        log_error "$(_ "system.reload.reboot_required" "$REBOOT_REQUIRED_FILE_PATH")"
        
        local pkgs_file="${REBOOT_REQUIRED_FILE_PATH}.pkgs"
        if [[ -f "$pkgs_file" ]]; then
            log_info "$(_ "system.reload.pkgs_header")"
            while IFS= read -r pkg; do
                log_info_simple_tab "$(_ "no_translate" "$pkg")"
            done < "$pkgs_file"
        fi
        return 4
    else
        log_info "$(_ "system.reload.not_required")"
    fi
}

# @type:        Orchestrator
# @description: Точка входа модуля проверки перезагрузки системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - перезагрузка не требуется
#               1 - требуется перезагрузка
main() {
    i18n::load
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
