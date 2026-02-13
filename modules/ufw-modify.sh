#!/usr/bin/env bash
# Изменяет состояние UFW
# MODULE_ORDER: 80
# MODULE_TYPE: modify
# MODULE_NAME: module.ufw.name

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Проверяет требования для запуска UFW модуля
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - требования выполнены
#               4 - требования не выполнены
ufw::rule::check_requirements() {
    if ufw::rule::has_any_bsss; then
        return
    fi

    if ufw::status::is_active; then
        log_info "$(_ "ufw.info.no_rules_but_active")"
        return
    else
        log_warn "$(_ "ufw.warning.continue_without_rules")"
        log_info "$(_ "ufw.warning.add_ssh_first")"
        log_bold_info "$(_ "common.helpers.ufw.rules.sync")"
        log_bold_info "$(_ "common.helpers.ufw.rules.delete_warning")"
        return 4
    fi
}

# @type:        Orchestrator
# @description: Переключает состояние UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
ufw::toggle::status() {
    if ufw::status::is_active; then
        ufw::status::force_disable
    else
        ufw::status::force_enable
    fi
}

# @type:        Orchestrator
# @description: Активирует UFW с watchdog и подтверждением подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отменено пользователем (подтверждение не получено)
#               1 - ошибка активации UFW
ufw::status::force_enable() {
    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ufw")
    ufw::log::rollback::instructions

    if ! ufw --force enable >/dev/null 2>&1; then
        rollback::orchestrator::immediate_usr2
        log_error "$(_ "ufw.error.enable_failed")"
        return 1
    fi

    log_info "$(_ "ufw.success.enabled")"
    log_actual_info
    ufw::log::status
    ufw::log::rules
    ufw::log::ping_status

    if io::ask_value "$(_ "ufw.install.confirm_connection")" "" "^connected$" "connected" "0" >/dev/null; then
        rollback::orchestrator::watchdog_stop
    else
        rollback::orchestrator::immediate_usr2
    fi
}

# @type:        Sink
# @description: Отображает инструкции пользователю для проверки подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
ufw::log::rollback::instructions() {
    log_attention "$(_ "ufw.rollback.warning_title")"
    log_attention "$(_ "ufw.rollback.test_access")"
}

# @type:        Orchestrator
# @description: Переключает состояние PING
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
ufw::toggle::ping() {
    if ufw::ping::is_configured; then
        ufw::ping::restore
    else
        ufw::orchestrator::disable_ping
    fi
    ufw::status::reload
}

# @type:        Orchestrator
# @description: Отключает пинг через UFW (бэкап + трансформация + reload)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки операции
ufw::orchestrator::disable_ping() {
    ufw::ping::backup_file
    ufw::ping::disable_in_rules
}

# @type:        Orchestrator
# @description: Заменяет ACCEPT на DROP в ICMP правилах файла before.rules
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки команды sed
ufw::ping::disable_in_rules() {
    if sed -i '/-p icmp/s/ACCEPT/DROP/g' "$UFW_BEFORE_RULES"; then
        log_info "$(_ "ufw.success.before_rules_edited" "$UFW_BEFORE_RULES")"
        log_info "$(_ "ufw.success.icmp_changed")"
    else
        log_error "$(_ "ufw.error.edit_failed" "$UFW_BEFORE_RULES")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Применяет изменения UFW на основе выбранного действия
# @params:
#   menu_id     ID выбранного действия
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка в процессе
ufw::orchestrator::dispatch_logic() {
    local menu_id="$1"

    case "$menu_id" in
        1) ufw::toggle::status ;;
        2) ufw::toggle::ping ;;
        *) log_error "$(_ "ufw.error.invalid_menu_id" "$menu_id")"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Запускает модуль UFW с механизмом rollback только при включении UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ufw::orchestrator::run_module() {
    #
    # Через пайп и сабшелл не получается потому что в get_user_choice есть read и он в случае пайпа запускается с иным PID
    # ufw::menu::get_user_choice | ufw::orchestrator::dispatch_logic
    #

    ufw::menu::display

    local menu_id
    menu_id=$(ufw::menu::get_user_choice | tr -d '\0')
    # Запускаем в текущем процессе, что бы корректно завершать read при получении сигнала отката SIGUSR1
    ufw::orchestrator::dispatch_logic "$menu_id"
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля изменения состояния UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отказ пользователя
#               4 - требования не выполнены
#               130 - прерывание по Ctrl+C
#               $? - ошибка выполнения модулей
main() {
    i18n::load
    log_start

    io::confirm_action "$(_ "ufw.modify.confirm")"

    ufw::rule::check_requirements

    ufw::orchestrator::run_module
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
