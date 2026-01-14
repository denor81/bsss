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

readonly WATCHDOG_FIFO="/tmp/bsss_watchdog_$$.fifo"
FIFO_READER_PID=""

# Сработает при откате изменений при сигнале USR1
trap 'exit 0' SIGUSR1

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
    ssh::log_bsss_configs

    log_info_simple_tab "1. Сброс (удаление правила ${UTIL_NAME^^})"
    log_info_simple_tab "2. Переустановка (замена на новый порт)"

    local user_action
    user_action=$(io::ask_value "Выберите" "" "^[12]$" "1/2" | tr -d '\0') || return

    case "$user_action" in
        1) ssh::reset_and_pass | ufw::reset_and_pass | orchestrator::actions_after_port_change ;;
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

# orchestrator::log_rollback_in_main_script() {
#     # log_info "ROLLBACK: Получен сигнал отката"
#     # kill "$FIFO_READER_PID" 2>/dev/null || true 
#     # wait "$FIFO_READER_PID" 2>/dev/null || true
#     # cat "$WATCHDOG_FIFO_PATH"
#     # rm -f "$WATCHDOG_FIFO_PATH"
#     exit 0
# }

# @type:        Orchestrator
# @description: Применение изменений с защитным таймером
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
orchestrator::install_new_port_w_guard() {

    local watchdog_pid
    local port
    port=$(ssh::ask_new_port | tr -d '\0') || return

    printf '%s\0' "$port" | ssh::reset_and_pass | ufw::reset_and_pass | ssh::install_new_port

    mkfifo "$WATCHDOG_FIFO"
    cat "$WATCHDOG_FIFO" >&2 & 
    # FIFO_READER_PID=$!

    nohup bash "${MODULES_DIR_PATH}/../${UTILS_DIR%/}/rollback.sh" "$$" "$WATCHDOG_FIFO" "$CURRENT_MODULE_NAME" >/tmp/rollback.debug 2>&1 &
    watchdog_pid=$!
    orchestrator::actions_after_port_change

    log::draw_lite_border
    log_info "rollback.sh таймер отката запущен (5 минут)... [PID: $watchdog_pid]"
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "ОТКРОЙТЕ НОВОЕ ОКНО ТЕРМИНАЛА и проверьте возможность подключения через порт $port"
    
    if io::ask_value "Для подтверждения введите connected" "" "^connected$" "connected" >/dev/null || return; then
        kill -USR1 "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true
        # kill "$FIFO_READER_PID" 2>/dev/null || true 
        # wait "$FIFO_READER_PID" 2>/dev/null || true
        log_success "Изменения зафиксированы"
        log_info "rollback.sh остановлен [PID: $watchdog_pid]"
    fi
}

main() {
    log_info "PID: $$"
    orchestrator::dispatch_logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
