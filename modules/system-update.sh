#!/usr/bin/env bash
# Обновляет системные пакеты
# MODULE_ORDER: 40
# MODULE_TYPE: modify
# MODULE_NAME: module.system.update.name

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/system-update.sh"

trap log_stop EXIT

# @type:        Orchestrator
# @description: Оркестратор процесса обновления системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка обновления
sys::update::orchestrator() {
    sys::update::get_command | sys::update::execute
}

# @type:        Orchestrator
# @description: Основная точка входа модуля обновления системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    i18n::load
    log_start
    io::confirm_action "$(_ "system.update.confirm")"
    sys::update::orchestrator
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
