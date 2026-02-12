#!/usr/bin/env bash
# Проверяет текущие права доступа SSH
# MODULE_ORDER: 12
# MODULE_TYPE: checkq
# MODULE_NAME: module.permissions.check.name

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions-helpers.sh"

trap log_stop EXIT

# @type:        Sink
# @description: Выводит информацию о текущем состоянии прав доступа SSH
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0
permissions::check::info() {
    local current_conn_type login_user root_id auth_id

    log_info "=== Проверка прав доступа SSH ==="

    current_conn_type=$(permissions::auth::get_method | tr -d '\0')
    login_user=$(logname 2>/dev/null || echo "N/A")
    root_id=$(id -u root)
    auth_id=$(id -u "$login_user")

    log_info "Текущее подключение: [$current_conn_type]"
    log_info "Текущий пользователь: [$login_user:$auth_id]"
    log_info "Root UID: [$root_id]"

    permissions::log::configs

    log_info ""
    log_info "=== Статус отключения логина по паролю и root ==="

    if [[ "$current_conn_type" != "PUBLICKEY" ]]; then
        log_warn "Требуется подключение по SSH ключу"
    elif (( root_id == auth_id )); then
        log_warn "Требуется подключение пользователем отличным от root"
    else
        log_info "Можно отключать PermitRootLogin и PasswordAuthentication"
    fi
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля проверки прав доступа
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    i18n::load
    log_start
    io::confirm_action "Запустить модуль?"
    permissions::check::info
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
