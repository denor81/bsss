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
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Инициирует немедленный откат через SIGUSR2 и ожидает завершения watchdog
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - откат выполнен, процесс заблокирован
permissions::orchestrator::trigger_immediate_rollback() {
    kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
    while true; do sleep 1; done
}

# @type:        Orchestrator
# @description: Отображает статусы permissions: BSSS правила, сторонние правила
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - Всегда успешно
permissions::orchestrator::log_statuses() {
    permissions::log::bsss_configs
    permissions::log::other_configs
}

# @type:        Orchestrator
# @description: Выполняет откат правил permissions и рестарт сервиса
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
permissions::orchestrator::restore::rules() {
    permissions::rules::restore
    sys::service::restart
    log_actual_info
    permissions::orchestrator::log_statuses
}

# @type:        Orchestrator
# @description: Создает правила permissions с механизмом rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
permissions::orchestrator::install::rules() {

    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "permissions")

    permissions::log::guard_instructions

    permissions::rules::make_bsss_rules
    sys::service::restart
    log_actual_info
    permissions::orchestrator::log_statuses

    if io::ask_value "$(_ "common.confirm_connection" "connected" "0")" "" "^connected$" "connected" "0" >/dev/null; then
        rollback::orchestrator::watchdog_stop
        log_info "$(_ "common.success_changes_committed")"
    else
        permissions::orchestrator::trigger_immediate_rollback
    fi
}

# @type:        Orchestrator
# @description: Запускает модуль с интерактивным меню
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно выполнено действие
#               2 - выход по выбору пользователя
#               $? - ошибка при выполнении действия
permissions::orchestrator::run_module() {
    log_info "$(_ "common.menu_header")"
    permissions::rules::is_configured && log_info_simple_tab "1. $(_ "permissions.menu.item_remove")" || log_info_simple_tab "1. $(_ "permissions.menu.item_create")"
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-1]$" "0-1" "0" | tr -d '\0') || return

    case "$menu_id" in
        1) permissions::toggle::rules ;;
        *) log_error "$(_ "common.error.invalid_menu_id" "$menu_id")"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Выполняет переключение правил в зависимости от состояния
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка при выполнении действия
permissions::toggle::rules() {
    if permissions::rules::is_configured; then
        permissions::orchestrator::restore::rules
    else
        log_info "$(_ "permissions.info.create_rules" "$SSH_CONFIGD_DIR")"
        log_info_simple_tab "$(_ "no_translate" "PermitRootLogin no")"
        log_info_simple_tab "$(_ "no_translate" "PasswordAuthentication no")"
        log_info_simple_tab "$(_ "no_translate" "PubkeyAuthentication yes")"
        if io::confirm_action; then
            permissions::orchestrator::install::rules
        fi
    fi
}

# @type:        Orchestrator
# @description: Проверяет текущего пользователя и запускает модуль
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - пользователь авторизован как root
permissions::orchestrator::check_current_user() {
    local root_id auth_id auth_type
    root_id=$(id -u root)
    auth_id=$(id -u "$(logname)")

    # user::info::block
    # log_info "[nosudo>нет прав sudo] [nopass>не требует пароль при выполнении sudo]"
    # log_info "[pass>требует пароль при выполнении sudo] [superuser>superuser]"
    permissions::orchestrator::log_statuses

    if (( root_id == auth_id )); then
        log_warn "$(_ "permissions.warn.auth_by_ssh_key_user")"
        log_warn "$(_ "permissions.warn.connect_ssh_key_not_root")"
        return 1
    fi

    permissions::orchestrator::run_module
}

# @type:        Orchestrator
# @description: Проверяет условия и запускает модуль при выполнении
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отмена пользователем или несоответствие условий
permissions::orchestrator::dispatch_logic() {
    local current_conn_type

    current_conn_type=$(sys::user::get_auth_method | tr -d '\0')

    log_info "$(_ "no_translate" "Владелец сессии [$(logname)]|Тип подключения [$current_conn_type]")"

    case "$current_conn_type" in
        key) permissions::orchestrator::check_current_user ;;
        pass)
            log_attention "$(_ "permissions.attention.password_connection")"
            log_warn "$(_ "permissions.warn.sudo_password_required")"
            log_warn "$(_ "permissions.warn.sudoers_file_instruction" "$SUDOERS_D_DIR/${BSSS_USER_NAME}" "${BSSS_USER_NAME}")"
            permissions::orchestrator::check_current_user
        ;;
        timeout)
            log_warn "$(_ "permissions.warn.session_timeout_limitations")"
            log_warn "$(_ "permissions.warn.reconnect_new_window" "$current_conn_type")"
            log_warn "$(_ "permissions.info.only_reset_available")"
            io::confirm_action "$(_ "permissions.confirm.reset_rules" "${UTIL_NAME^^}")"
            permissions::orchestrator::restore::rules
        ;;
        n/a) log_warn "$(_ "permissions.warn.cannot_determine_connection")"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля создания прав доступа
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    i18n::load
    log_start
    permissions::orchestrator::dispatch_logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
