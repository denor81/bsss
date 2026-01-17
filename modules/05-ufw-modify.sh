#!/usr/bin/env bash
# Изменяет состояние UFW
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"
source "${MODULES_DIR_PATH}/../lib/user_confirmation.sh"
source "${MODULES_DIR_PATH}/common-helpers.sh"
source "${MODULES_DIR_PATH}/05-ufw-helpers.sh"

trap 'exit 0' SIGUSR1
trap log_stop EXIT

# @type:        Orchestrator
# @description: Основная функция управления состоянием UFW с watchdog для включения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
orchestrator::run_ufw_module() {
    local was_active_before
    was_active_before=$(ufw::is_active && echo "1" || echo "0")
    
    # вернет код 2 при выходе 0 [ufw::select_action->io::ask_value->return 2]
    if ufw::get_menu_items | tee >(ufw::display_menu) | ufw::select_action | ufw::execute_action; then
        # Проверяем, был ли UFW включен (был неактивен, стал активен)
        local is_active_now
        is_active_now=$(ufw::is_active && echo "1" || echo "0")
        
        if [[ "$was_active_before" == "0" ]] && [[ "$is_active_now" == "1" ]]; then
            # UFW был включен - запускаем watchdog
            orchestrator::enable_ufw_w_guard
        else
            # UFW был выключен или уже был активен
            orchestrator::actions_after_ufw_change
        fi
    else
        local exit_code=$?
        case "$exit_code" in
            2) log_info "Выход [Code: $exit_code]"; return "$exit_code" ;;
            *) log_error "Сбой в цепочке UFW [Code: $exit_code]"; return "$exit_code" ;;
        esac
    fi
}

# @type:        Orchestrator
# @description: Выполняет включение UFW с защитным таймером
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
orchestrator::enable_ufw_w_guard() {
    local watchdog_fifo="/tmp/bsss_watchdog_$$.fifo"
    local watchdog_pid

    # Запускаем сторожевой таймер с типом отката "ufw"
    watchdog_pid=$(orchestrator::start_watchdog "ufw" | tr -d '\0') || return

    log::draw_lite_border
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "ОТКРОЙТЕ НОВОЕ ОКНО ТЕРМИНАЛА и проверьте доступ к серверу"

    orchestrator::actions_after_ufw_change
    
    if io::ask_value "Подтвердите успешное подключение к серверу - введите 'connected'" "" "^connected$" "connected" >/dev/null || return; then
        orchestrator::stop_watchdog "$watchdog_pid" "$watchdog_fifo"
        log_success "Изменения зафиксированы"
    fi
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля изменения состояния UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    log_start

    # Запуск или возврат кода 2 при отказе пользователя
    if io::confirm_action "Изменить состояние UFW?"; then
        orchestrator::run_ufw_module
    else
        return
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
