#!/usr/bin/env bash
# Изменяет состояние UFW
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/common-helpers.sh"
source "${PROJECT_ROOT}/modules/05-ufw-helpers.sh"

WATCHDOG_FIFO="$PROJECT_ROOT/bsss_watchdog_$$.fifo"

# Сработает при откате изменений при сигнале USR1
trap log_stop EXIT
trap stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Запускает модуль UFW с механизмом rollback только при включении UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ufw::orchestrator::run_module() {
    local watchdog_pid=""
    local action_id
    local watchdog_started=false

    # 1. Отображение меню
    ufw::menu::display

    # 2. Получение выбора пользователя (точка возврата кода 2)
    action_id=$(ufw::menu::get_user_choice | tr -d '\0') || return

    # 3. Rollback только при включении UFW (action_id=1 и UFW сейчас выключен)
    #    Отключение UFW безопасно и не требует rollback
    #    Управление PING (action_id=2) не является критическим
    if [[ "$action_id" == "1" ]] && ! ufw::rule::is_active; then
        make_fifo_and_start_reader
        watchdog_pid=$(rollback::orchestrator::watchdog_start "$WATCHDOG_FIFO")
        watchdog_started=true
        rollback::orchestrator::guard_ui_instructions
    fi

    # 4. Внесение изменений
    ufw::rule::apply_changes "$action_id"

    # 5. Действия после изменений
    ufw::orchestrator::actions_after_ufw_change

    # 6. Подтверждение и остановка Rollback (только при включении UFW)
    if [[ "$watchdog_started" == true ]]; then
        if ufw::ui::confirm_success; then
            rollback::orchestrator::watchdog_stop "$watchdog_pid"
        fi
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
    printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
    exit 3
}

# @type:        Orchestrator
# @description: Запускает фоновый процесс rollback (watchdog)
# @params:
#   watchdog_fifo путь к FIFO для коммуникации
# @stdin:       нет
# @stdout:      PID процесса watchdog
# @exit_code:   0 - успешно
rollback::orchestrator::watchdog_start() {
    local rollback_module="${PROJECT_ROOT}/${UTILS_DIR}/$ROLLBACK_MODULE_NAME"

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
rollback::orchestrator::watchdog_stop() {
    local watchdog_pid="$1"
    # Посылаем сигнал успешного завершения (USR1)
    kill -USR1 "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    log_info "Изменения зафиксированы, Rollback отключен"
    printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
}

# @type:        Sink
# @description: Отображает инструкции пользователю для проверки подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
rollback::orchestrator::guard_ui_instructions() {
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
        ufw::orchestrator::run_module
    else
        return
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
