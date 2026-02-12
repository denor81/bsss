#!/usr/bin/env bash
# Проверяет состояние пользователей системы
# MODULE_ORDER: 11
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"

# @type:        Orchestrator
# @description: Проверяет состояние пользователей системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
check() {
    user::info::block
    user::log::configs
}

# @type:        Orchestrator
# @description: Точка входа модуля проверки пользователей
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - проверка прошла успешно
main() {
    i18n::load
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
