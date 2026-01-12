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
    user_action=$(io::ask_value "Выберите" "" "^[12]$" "1/2") || return

    case "$user_action" in
        1) ssh::reset_and_pass | ufw::reset_and_pass ;;
        2) orchestrator::install_new_port_w_guard ;;
    esac
    orchestrator::actions_after_port_change
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
    orchestrator::actions_after_port_change
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

    local watchdog_init
    watchdog_init=$(declare -f orchestrator::watchdog_timer orchestrator::total_rollback \
                   ssh::delete_all_bsss_rules ufw::force_disable ufw::delete_all_bsss_rules \
                   orchestrator::actions_after_port_change log_warn log_success)

    local watchdog_cmd
    watchdog_cmd="source "${MODULES_DIR_PATH}/../lib/vars.conf"; \
                    source "${MODULES_DIR_PATH}/../lib/logging.sh"; \
                    source "${MODULES_DIR_PATH}/../lib/user_confirmation.sh"; \
                    source "${MODULES_DIR_PATH}/common-helpers.sh"; \
                    source "${MODULES_DIR_PATH}/04-ssh-port-helpers.sh"; \
                    orchestrator::watchdog_timer $current_pid;"

    orchestrator::install_new_port
    nohup bash -c "$watchdog_cmd">bsss_watchdog.log 2>&1 &
    local watchdog_pid=$!
    orchestrator::actions_after_port_change

    # 3. Ожидание подтверждения
    log::draw_lite_border
    log_info_simple_tab "Запуск таймера безопасности (5 минут)... [PID: $$watchdog_pid]"
    log_info_simple_tab "ВНИМАНИЕ: Настройки применены."
    log_info_simple_tab "1. ОТКРОЙТЕ НОВОЕ ОКНО ТЕРМИНАЛА."
    log_info_simple_tab "2. Попробуйте подключиться по новому порту."
    log_info_simple_tab "Если вы не подтвердите связь, через 5 минут произойдет ОТКАТ."
    
    if io::ask_value "Для подтверждения введите 'connected'" "" "^connected$" "слово 'connected'"; then
        # Если ввели верно - убиваем таймер
        kill "$watchdog_pid" 2>/dev/null || true
        log_success "Изменения зафиксированы. Таймер отката отключен. [kill $$watchdog_pid]"
    fi
}

main() {
    orchestrator::dispatch_logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
