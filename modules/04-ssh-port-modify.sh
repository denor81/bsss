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

declare WATCHDOG_PID

trap 'orchestrator::log_rollback_in_main_script' SIGUSR1

orchestrator::log_rollback_in_main_script() {
    printf '\n' >&2
    log_info "Время истекло - запущен ROLLBACK"

    # читаем лог в реальном времени
    tail -n +1 -f --pid="$WATCHDOG_PID" "${MODULES_DIR_PATH}/../bsss_watchdog.log" | awk '
        {
            if ($0 ~ /EOF/) exit 0;
            print $0;
            fflush();
        }
    ' >&2 || true
    exit 0
}

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

orchestrator::install_new_port() {
    ssh::ask_new_port | ssh::reset_and_pass | ufw::reset_and_pass | ssh::install_new_port
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
    local current_pid=$$
    log_info "BSSS_PID: $current_pid"

    local port
    port=$(orchestrator::install_new_port | tr -d '\0') || return
    nohup bash "${MODULES_DIR_PATH}/../${UTILS_DIR%/}/rollback.sh" "$current_pid">"${MODULES_DIR_PATH}/../bsss_watchdog.log" 2>&1 &
    WATCHDOG_PID=$!
    orchestrator::actions_after_port_change

    log::draw_lite_border
    log_info "Запуск таймера отката (5 минут)..."
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "ОТКРОЙТЕ НОВОЕ ОКНО ТЕРМИНАЛА и проверьте возможность подключения через порт $port"
    
    if io::ask_value "Для подтверждения введите connected" "" "^connected$" "connected" >/dev/null || return; then
        kill -USR1 "$WATCHDOG_PID" 2>/dev/null || true
        wait "$WATCHDOG_PID" 2>/dev/null || true
        log_success "Изменения зафиксированы. Таймер отката отключен."
    fi
}

main() {
    orchestrator::dispatch_logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
