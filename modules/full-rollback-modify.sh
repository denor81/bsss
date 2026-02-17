#!/usr/bin/env bash
# Полный откат всех настроек BSSS

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"

trap common::int::actions INT
trap common::exit::actions EXIT

# @type:        Orchestrator
# @description: Выполняет полный откат всех настроек BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - все откаты выполнены (даже если с ошибками)
full_rollback::orchestrator::execute_all() {
    permissions::rules::restore || true
    ssh::rule::delete_all_bsss || true
    ufw::rule::delete_all_bsss || true
    ufw::status::force_disable || true
    ufw::ping::restore || true
    sys::service::restart || true
    log_success "$(_ "rollback.system_restored")"
}

full_rollback::orchestrator::run_module() {
    full_rollback::orchestrator::execute_all
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля полного отката
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    i18n::load
    log_start
    full_rollback::orchestrator::run_module
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
