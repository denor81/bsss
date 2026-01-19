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

orchestrator::install_new_port_w_guard() {
    local port
    local watchdog_fifo="$MODULES_DIR_PATH/../bsss_watchdog_$$.fifo"
    local watchdog_pid
    local reader_pid

    # 1. Сбор данных
    ssh::display_menu
    port=$(ssh::ask_new_port | tr -d '\0') || return

    # 2. Модификация
    printf '%s\0' "$port" | ssh::reset_and_pass | ufw::reset_and_pass | ssh::install_new_port

    # 3. Создаю FIFO и запускаю слушателя
    make_fifo_and_start_reader "$watchdog_fifo"

    # 4. Запуск Rollback
    watchdog_pid=$(orchestrator::watchdog_start "$watchdog_fifo")

    # 5. Интерактивное подтверждение
    orchestrator::guard_ui_instructions "$port"

    # 6. Перезагрузка служб только после запука Rollback и инструкций
    orchestrator::actions_after_port_change
    
    # 7. Проверка поднятия порта
    if ! ssh::wait_for_port_up "$port"; then
        trap "stop_script_by_rollback_timer '$watchdog_fifo'" SIGUSR1
        kill -USR2 "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true

        # Заглушка для ожидания отката через сигнал от rollback.sh
        while true; do sleep 1; done 
    fi

    # 8. Подтверждение и остановка Rollback
    if io::ask_value "Подтвердите подключение - введите connected" "" "^connected$" "connected" >/dev/null; then
        orchestrator::watchdog_stop "$watchdog_pid"
    fi
}

make_fifo_and_start_reader() {
    local watchdog_fifo="$1"

    mkfifo "$watchdog_fifo"
    log_info "Создан FIFO: $watchdog_fifo"
    cat "$watchdog_fifo" >&2 &
}

stop_script_by_rollback_timer() {
    printf '%s\0' "$1" | sys::delete_paths
    exit 3
}

orchestrator::watchdog_start() {
    local watchdog_fifo="$1"
    local rollback_module="${MODULES_DIR_PATH}/../${UTILS_DIR%/}/$ROLLBACK_MODULE_NAME"

    # Запускаем "Сторожа" отвязано от терминала
    # Передаем PID основного скрипта ($$) первым аргументом
    nohup bash "$rollback_module" "$$" "$watchdog_fifo" >/dev/null 2>&1 &
    printf '%s' "$!" # Возвращаем PID для оркестратора
}

orchestrator::watchdog_stop() {
    local watchdog_pid="$1"
    # Посылаем сигнал успешного завершения (USR1)
    kill -USR1 "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    log_info "Изменения зафиксированы, Rollback отключен"
}

orchestrator::guard_ui_instructions() {
    local port="$1"
    log::draw_lite_border
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "ОТКРОЙТЕ НОВОЕ ОКНО и проверьте связь через порт $port"
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
