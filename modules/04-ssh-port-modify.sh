#!/usr/bin/env bash
# Изменяет SSH порт
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/common-helpers.sh"
source "${PROJECT_ROOT}/modules/04-ssh-port-helpers.sh"

# Сработает при откате изменений при сигнале USR1
trap log_stop EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Определяет состояние конфигурации SSH (существует/отсутствует) 
#               и переключает логику модуля на соответствующий сценарий.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
ssh::orchestrator::dispatch_logic() {

    if sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | read -r -d '' _; then
        ssh::orchestrator::config_exists
    else
        ssh::orchestrator::config_not_exists
    fi
}

# @type:        Orchestrator
# @description: Интерфейс выбора действий при наличии существующих конфигов
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
ssh::orchestrator::config_exists() {
    ssh::config::log_bsss_with_ports

    log_info "Доступные действия:"
    log_info_simple_tab "1. Сброс (удаление правила ${UTIL_NAME^^})"
    log_info_simple_tab "2. Переустановка (замена на новый порт)"
    log_info_simple_tab "0. Выход"

    local user_action
    user_action=$(io::ask_value "Выберите" "" "^[012]$" "0-2" "0" | tr -d '\0') || return

    case "$user_action" in
        1) ssh::rule::reset_and_pass | ufw::rule::reset_and_pass; ssh::orchestrator::actions_after_port_change ;;
        2) ssh::orchestrator::install_port_with_guard ;;
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
ssh::orchestrator::config_not_exists() {
    ssh::orchestrator::install_port_with_guard
}

# @type:        Orchestrator
# @description: Запускает модуль SSH с механизмом rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ssh::orchestrator::install_port_with_guard() {
    local watchdog_pid
    local port

    # 1. Отображение меню
    log::draw_lite_border
    log_info "Доступные действия:"
    log_info_simple_tab "0. Выход"

    # 2. Получение выбора пользователя (точка возврата кода 2)
    port=$(ssh::ui::get_new_port | tr -d '\0') || return

    # 3. Создание FIFO и запуск слушателя
    make_fifo_and_start_reader

    # 4. Запуск Rollback (ДО внесения изменений!)
    watchdog_pid=$(rollback::orchestrator::watchdog_start "$WATCHDOG_FIFO")

    # 5. Интерактивные инструкции
    orchestrator::guard_ui_instructions "$port"

    # 6. Внесение изменений
    ssh::rule::apply_changes "$port"

    # 7. Действия после изменений
    ssh::orchestrator::actions_after_port_change

    # 8. Проверка поднятия порта
    if ! ssh::port::wait_for_up "$port"; then
        kill -USR2 "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true
        # Заглушка для ожидания отката через сигнал от rollback.sh
        while true; do sleep 1; done
    fi

    # 9. Подтверждение и остановка Rollback
    if io::ask_value "Подтвердите подключение - введите connected" "" "^connected$" "connected" >/dev/null; then
        rollback::orchestrator::watchdog_stop "$watchdog_pid"
        log_info "Изменения зафиксированы, Rollback отключен"
    fi
}

common::rollback::stop_script_by_rollback_timer() {
    printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
    exit 3
}

# rollback::orchestrator::watchdog_stop() {
#     local watchdog_pid="$1"
#     # Посылаем сигнал успешного завершения (USR1)
#     kill -USR1 "$watchdog_pid" 2>/dev/null || true
#     wait "$watchdog_pid" 2>/dev/null || true
#     printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
# }

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
        ssh::orchestrator::dispatch_logic
    else
        return
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
