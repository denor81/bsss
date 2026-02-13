#!/usr/bin/env bash
# Создает файл конфигурации SSH для отключения логина по паролю и root
# MODULE_ORDER: 26
# MODULE_TYPE: modify
# MODULE_NAME: module.permissions.modify.name

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

permissions::orchestrator::toggle_logic() {
    local menu_id

    permissions::menu::display
    menu_id=$(permissions::menu::get_user_choice | tr -d '\0')

    case "$menu_id" in
        1) permissions::toggle::rules ;;
        *) log_error "$(_ "ufw.error.invalid_menu_id" "$menu_id")"; return 1 ;;
    esac
}

permissions::orchestrator::check_current_user() {
    local root_id auth_id auth_type
    root_id=$(id -u root)
    auth_id=$(id -u "$(logname)")

    log_info "[nosudo>нет прав sudo] [nopass>не требует пароль при выполнении sudo]"
    log_info "[pass>требует пароль при выполнении sudo] [superuser>superuser]"
    user::info::block

    if (( root_id == auth_id )); then
        log_warn "Авторизируйтесь по SSH ключу обычным пользователем"
        log_warn "Подключитесь по SSH ключу пользователем отличным от root"
        return 1
    fi

    permissions::orchestrator::toggle_logic 
}

# @type:        Orchestrator
# @description: Проверяет условия и создает файл конфигурации при выполнении
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отмена пользователем или несоответствие условий
permissions::orchestrator::dispatch_logic() {
    local current_conn_type

    current_conn_type=$(user::system::get_auth_method | tr -d '\0')

    case "$current_conn_type" in
        key) 
            log_info "Владелец сессии [$(logname)]|Тип подключения [$current_conn_type]"
            permissions::orchestrator::check_current_user
        ;;
        pass) log_warn "Подключитесь по SSH ключу пользователем отличным от root"; return 1 ;;
        timeout) 
            log_warn "Сессия длиннее 72 часов [невозможно определить тип подключения - ограничения журнала]"
            log_warn "Подключитесь заново в новом окне нерминала ["$current_conn_type"]"
            log_warn "В таком режиме возможен только сброс настроек"
            io::confirm_action "Выполнить сброс правил ${UTIL_NAME^^} для доступа?"
            permissions::orchestrator::restore::rules
        ;;
        n/a) log_warn "Не удалось определить тип подключения"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля создания прав доступа
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отмена пользователем или несоответствие условий
main() {
    i18n::load
    log_start
    io::confirm_action "Запустить модуль?"
    permissions::orchestrator::dispatch_logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
