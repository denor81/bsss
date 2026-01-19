#!/usr/bin/env bash
# Изменяет SSH порт
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"
source "${MODULES_DIR_PATH}/../lib/user_confirmation.sh"
source "${MODULES_DIR_PATH}/common-helpers.sh"
source "${MODULES_DIR_PATH}/04-ssh-port-helpers.sh"

# Сработает при откате изменений при сигнале USR1
trap 'exit 0' SIGUSR1
trap log_stop EXIT

# @type:        Orchestrator
# @description: Определяет состояние конфигурации SSH (существует/отсутствует) 
#               и переключает логику модуля на соответствующий сценарий.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
orchestrator::dispatch_logic() {

    if sys::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | read -r -d '' _; then
        orchestrator::bsss_config_exists
    else
        orchestrator::bsss_config_not_exists
    fi
}

# @type:        Orchestrator
# @description: Интерфейс выбора действий при наличии существующих конфигов
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
orchestrator::bsss_config_exists() {
    ssh::log_bsss_configs_w_port

    log_info_simple_tab "1. Сброс (удаление правила ${UTIL_NAME^^})"
    log_info_simple_tab "2. Переустановка (замена на новый порт)"

    local user_action
    user_action=$(io::ask_value "Выберите" "" "^[12]$" "1/2" | tr -d '\0') || return

    case "$user_action" in
        1) ssh::reset_and_pass | ufw::reset_and_pass; orchestrator::actions_after_port_change ;;
        2) orchestrator::install_new_port_w_guard ;;
    esac
}

# @type:        Orchestrator
# @description: Обработчик сценария отсутствия конфигурации SSH
#               Установка нового порта SSH и добавление правила в UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 — упешно
#               $? — код ошибки дочернего процесса
orchestrator::bsss_config_not_exists() {
    orchestrator::install_new_port_w_guard
}

# @type:        Orchestrator
# @description: Применение изменений с защитным таймером
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
orchestrator::install_new_port_w_guard() {
    local watchdog_fifo="/tmp/bsss_watchdog_$$.fifo"
    local watchdog_pid
    local port
    local rollback_module_name="rollback.sh"

    ssh::display_menu
    port=$(ssh::ask_new_port | tr -d '\0') || return

    printf '%s\0' "$port" | ssh::reset_and_pass | ufw::reset_and_pass | ssh::install_new_port

    mkfifo "$watchdog_fifo"
    cat "$watchdog_fifo" >&2 &

    nohup bash "${MODULES_DIR_PATH}/../${UTILS_DIR%/}/$rollback_module_name" "$$" "$watchdog_fifo">/dev/null 2>&1 &
    watchdog_pid=$!

    log::draw_lite_border
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "ОТКРОЙТЕ НОВОЕ ОКНО ТЕРМИНАЛА и проверьте возможность подключения через порт $port"

    orchestrator::actions_after_port_change
    
    if io::ask_value "Подтвердите успешное подключение - введите $port" "" "^$port$" "$port" >/dev/null || return; then
        kill -USR1 "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true
        log_success "Изменения зафиксированы"
    fi
    printf '%s\0' "$watchdog_fifo" | sys::delete_paths 2>/dev/null
}

main() {
    log_start
    
    # Запуск или возврат кода 2 при отказе пользователя
    if io::confirm_action "Изменить конфигурацию SSH порта?"; then
        orchestrator::dispatch_logic
    else
        return
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
