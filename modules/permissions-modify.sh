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

    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "$(_ "common.exit" "0")"

    if io::ask_value "$(_ "common.confirm_connection" "connected" "0")" "" "^connected$" "connected" "0" >/dev/null; then
        rollback::orchestrator::watchdog_stop
        log_info "$(_ "common.success_changes_committed")"
    else
        permissions::orchestrator::trigger_immediate_rollback
    fi
}

# @type:        Orchestrator
# @description: Обрабатывает выбор пользователя из меню и выполняет соответствующее действие
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - неверный выбор меню
permissions::orchestrator::toggle_logic() {
    local menu_id action

    permissions::menu::display
    menu_id=$(permissions::menu::get_user_choice | tr -d '\0')

    case "$menu_id" in
        1)
            action=$(permissions::toggle::rules | tr -d '\n')
            case "$action" in
                restore) permissions::orchestrator::restore::rules ;;
                install) 
                    log_info "Будет создан файл с правилами в каталоге $SSH_CONFIGD_DIR"
                    log_info_simple_tab "PermitRootLogin no"
                    log_info_simple_tab "PasswordAuthentication no"
                    log_info_simple_tab "PubkeyAuthentication yes"
                    io::confirm_action "$(_ "io.confirm_action.default_question")"
                    permissions::orchestrator::install::rules
                ;;
            esac
            ;;
        *) log_error "$(_ "ufw.error.invalid_menu_id" "$menu_id")"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Проверяет текущего пользователя и запускает логику переключения
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

    current_conn_type=$(sys::user::get_auth_method | tr -d '\0')

    log_info "Владелец сессии [$(logname)]|Тип подключения [$current_conn_type]"

    case "$current_conn_type" in
        key) permissions::orchestrator::check_current_user ;;
        pass)
            log_attention "Обнаружено подключение по паролю"
            log_warn "Вам придется вводить пароль каждый раз при sudo"
            log_warn "Для того, что бы пароль не запрашивался нужно создать файл-правило [$SUDOERS_D_DIR/${BSSS_USER_NAME}] со строкой [${BSSS_USER_NAME} ALL=(ALL) NOPASSWD:ALL] и установить права на файл [chmod 0440] после этого пароль в сессии запрашиваться не будет, либо создать пользователя через пункт меню - там все настраивается автоматически"
            permissions::orchestrator::check_current_user
        ;;
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
