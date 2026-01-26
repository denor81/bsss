#!/usr/bin/env bash
# Изменяет состояние UFW
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/common-helpers.sh"
source "${PROJECT_ROOT}/modules/05-ufw-helpers.sh"

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
    #
    # Через пайп и сабшелл не получается потому что в get_user_choice есть блокирующй read и он вешает терминал при откате
    # ufw::menu::get_user_choice | ufw::orchestrator::apply_changes
    #

    ufw::menu::display

    local menu_id
    menu_id=$(ufw::menu::get_user_choice | tr -d '\0') || return
    # Запускаем в текущем процессе, что бы корректно завершать read при получении сигнала отката SIGUSR1
    ufw::orchestrator::apply_changes "$menu_id"
}

# @type:        Orchestrator
# @description: Обработчик сигнала SIGUSR1 - останавливает скрипт при откате
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   3 - код завершения при откате
stop_script_by_rollback_timer() {
    log_info "Получен сигнал USR1 - остановка скрипта из-за отката"
    printf '%s\0' "$WATCHDOG_FIFO" | sys::file::delete
    exit 3
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
