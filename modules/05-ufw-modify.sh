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

WATCHDOG_FIFO="$MODULES_DIR_PATH/../bsss_watchdog_$$.fifo"

# Сработает при откате изменений при сигнале USR1
trap log_stop EXIT
trap stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Запускает модуль UFW с механизмом rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
orchestrator::run_ufw_module() {
    local watchdog_pid
    local action_id

    # 1. Отображение меню
    ufw::display_menu

    # 2. Получение выбора пользователя (точка возврата кода 2)
    action_id=$(ufw::get_user_choice | tr -d '\0') || return

    # 3. Создание FIFO и запуск слушателя
    make_fifo_and_start_reader

    # 4. Запуск Rollback (ДО внесения изменений!)
    watchdog_pid=$(orchestrator::watchdog_start "$WATCHDOG_FIFO")

    # 5. Интерактивные инструкции
    orchestrator::guard_ui_instructions

    # 6. Внесение изменений
    ufw::apply_changes "$action_id"

    # 7. Действия после изменений
    orchestrator::actions_after_ufw_change

    # 8. Подтверждение и остановка Rollback
    if ufw::confirm_success; then
        orchestrator::watchdog_stop "$watchdog_pid"
    fi
}

# @type:        Orchestrator
# @description: Создает FIFO и запускает слушатель для коммуникации с rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
make_fifo_and_start_reader() {
    mkfifo "$WATCHDOG_FIFO"
    log::new_line
    log_info "Создан FIFO: $WATCHDOG_FIFO"
    cat "$WATCHDOG_FIFO" >&2 &
}

# @type:        Orchestrator
# @description: Обработчик сигнала SIGUSR1 - останавливает скрипт при откате
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   3 - код завершения при откате
stop_script_by_rollback_timer() {
    printf '%s\0' "$WATCHDOG_FIFO" | sys::delete_paths
    exit 3
}

# @type:        Orchestrator
# @description: Запускает фоновый процесс rollback (watchdog)
# @params:
#   watchdog_fifo путь к FIFO для коммуникации
# @stdin:       нет
# @stdout:      PID процесса watchdog
# @exit_code:   0 - успешно
orchestrator::watchdog_start() {
    local rollback_module="${MODULES_DIR_PATH}/../${UTILS_DIR%/}/$ROLLBACK_MODULE_NAME"

    # Запускаем "Сторожа" отвязано от терминала
    # Передаем PID основного скрипта ($$) первым аргументом
    ROLLBACK_TYPE="ufw" nohup bash "$rollback_module" "$$" "$WATCHDOG_FIFO" >/dev/null 2>&1 &
    printf '%s' "$!" # Возвращаем PID для оркестратора
}

# @type:        Orchestrator
# @description: Останавливает процесс rollback (watchdog) по PID
# @params:
#   watchdog_pid PID процесса watchdog для остановки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
orchestrator::watchdog_stop() {
    local watchdog_pid="$1"
    # Посылаем сигнал успешного завершения (USR1)
    kill -USR1 "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    log_info "Изменения зафиксированы, Rollback отключен"
    printf '%s\0' "$WATCHDOG_FIFO" | sys::delete_paths
}

# @type:        Sink
# @description: Отображает инструкции пользователю для проверки подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
orchestrator::guard_ui_instructions() {
    log::draw_lite_border
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "Проверьте доступ к серверу после включения UFW"
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
