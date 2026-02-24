#!/usr/bin/env bash
# Изменяет SSH порт

#
# return 3 exit 3 возвращается при получении сигнала USR1 (common::rollback::stop_script_by_rollback_timer())
#

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# === ORCHESTRATORS ===

# @type:        Orchestrator
# @description: Устанавливает новый SSH порт с механизмом rollback
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешная установка порта
#               2 отмена пользователем
#               $? другие не определенные ошибки
ssh::install::port() {
    local port

    port=$(ssh::ui::get_new_port | tr -d '\0') || return

    make_fifo_and_start_reader
    
    start_sync_rollback
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ssh")
    stop_sync_rollback

    ssh::log::guard_instructions "$port"

    printf '%s\0' "$port" | ssh::rule::reset_and_pass | ufw::rule::reset_and_pass | ssh::port::install_new

    sys::service::restart
    if ! ssh::port::wait_for_up "$port"; then
        ssh::orchestrator::trigger_immediate_rollback
    fi
    
    log_actual_info
    common::log::current_config "^port"
    ssh::orchestrator::log_statuses
    ufw::log::rules

    if io::ask_value "$(_ "common.confirm_connection" "connected" "0")" "" "^connected$" "connected" "^0$" >/dev/null; then
        rollback::orchestrator::watchdog_stop
        log_info "$(_ "common.success_changes_committed")"
    else
        ssh::orchestrator::trigger_immediate_rollback
    fi
}

# @type:        Orchestrator
# @description: Отображает меню и диспетчеризирует выбор пользователя
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешное выполнение действия
#               2 выход по выбору пользователя
#               $? другие не определенные ошибки
ssh::main::menu::dispatcher() {
    ssh::log::active_ports_from_ss
    ssh::log::bsss_configs

    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "1. $(_ "ssh.menu.item_reset")"
    log_info_simple_tab "2. $(_ "ssh.menu.item_reinstall")"
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-2]$" "0-2" "^0$" | tr -d '\0') || return

    case "$menu_id" in
        1) ssh::reset::port ;;
        2) ssh::install::port ;;
    esac
}

# === SSH ORCHESTRATORS ===

# @type:        Orchestrator
# @description: Сбрасывает SSH порт и удаляет все BSSS правила
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешный сброс
#               $? другие не определенные ошибки
ssh::reset::port() {
    ssh::rule::reset_and_pass | ufw::rule::reset_and_pass
    ufw::status::force_disable # Для гарантированного доступа
    ufw::ping::is_configured && ufw::ping::restore

    sys::service::restart
    log_actual_info
    ssh::orchestrator::log_statuses
    ufw::log::rules
}

# @type:        Orchestrator
# @description: Обрабатывает сценарий с существующими конфигами
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешная обработка
#               2 отмена пользователем
#               $? другие не определенные ошибки
ssh::orchestrator::config_exists_handler() {
    ssh::main::menu::dispatcher
}

# @type:        Orchestrator
# @description: Обрабатывает сценарий отсутствия конфигов
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешная обработка
#               2 отмена пользователем
#               $? другие не определенные ошибки
ssh::orchestrator::config_not_exists_handler() {
    ssh::install::port
}

# @type:        Orchestrator
# @description: Определяет состояние конфигурации SSH и переключает логику модуля
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешное определение и запуск сценария
#               2 отмена пользователем
#               $? другие не определенные ошибки
ssh::orchestrator::dispatch_logic() {
    if sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" >/dev/null; then
        ssh::orchestrator::config_exists_handler
    else
        ssh::orchestrator::config_not_exists_handler
    fi
}

# @type:        Orchestrator
# @description: Запускает модуль изменения SSH порта
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешный запуск модуля
#               2 отмена пользователем
#               $? другие не определенные ошибки
ssh::orchestrator::run_module() {
    ssh::orchestrator::dispatch_logic
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля изменения SSH порта
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешное выполнение
#               $? другие не определенные ошибки
main() {
    i18n::load
    log_start
    ssh::orchestrator::run_module
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
