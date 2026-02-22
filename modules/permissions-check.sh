#!/usr/bin/env bash
# Проверяет текущие права доступа SSH

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"

# @type:        Orchestrator
# @description: Отображает информацию о текущем состоянии прав доступа SSH
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
permissions::check::info() {
    permissions::orchestrator::log_statuses
}

# @type:        Orchestrator
# @description: Запускает модуль проверки прав доступа
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 критическая ошибка загрузки переводов
main() {
    i18n::load
    permissions::check::info
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
