#!/usr/bin/env bash
# Обновляет системные пакеты

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/system-update.sh"

trap log_stop EXIT

# @type:        Orchestrator
# @description: Оркестрирует процесс обновления системы
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка обновления
sys::update::orchestrator() {
    sys::update::get_command | sys::update::execute
}

# @type:        Orchestrator
# @description: Запускает основную точку входа модуля обновления системы
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
main() {
    i18n::load
    log_start
    io::confirm_action "$(_ "system.update.confirm")"
    sys::update::orchestrator
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
