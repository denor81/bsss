#!/usr/bin/env bash
# Автоматическая настройка системы

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"

trap common::int::actions INT
trap common::exit::actions EXIT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Инициирует немедленный откат через SIGUSR2 и ожидает завершения watchdog
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - откат выполнен, процесс заблокирован
auto::orchestrator::trigger_immediate_rollback() {
    kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
    while true; do sleep 1; done
}

auto::install::check() {
    user::info::block
    permissions::check::current_user # возможно прерывание кодом 4
}

# @type:        Orchestrator
# @description: Выполняет автоматическую настройку с механизмом rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               4 - при необходимости авторизации по SSH ключу
#               $? - код ошибки дочернего процесса
auto::install::run() {
    auto::install::check # возможно прерывание кодом 4

    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "full")

    local port
    port=$(ssh::port::generate_free_random_port | tr -d '\0')

    ssh::log::guard_instructions "$port"

    printf '%s\0' "$port" | ssh::rule::reset_and_pass | ufw::rule::reset_and_pass | ssh::port::install_new

    if ufw::ping::is_configured; then
        ufw::ping::restore
    fi
    ufw::orchestrator::disable_ping
    ufw::status::force_enable
    permissions::rules::make_bsss_rules
    sys::service::restart

    log_actual_info
    ssh::orchestrator::log_statuses
    ufw::orchestrator::log_statuses
    permissions::orchestrator::log_statuses

    log_actual_info "Откройте новый терминал и выполните подключение по SSH ключу через порт $port. Если не удается подключиться - введите 0 для отмены и отката созанных изменений или подтвердите успешное подключение для фиксации изменений и отключения таймера отката."
    if io::ask_value "$(_ "common.confirm_connection" "connected" "0")" "" "^connected$" "connected" "0" >/dev/null; then
        rollback::orchestrator::watchdog_stop "$WATCHDOG_PID"
        log_info "$(_ "common.success_changes_committed")"
    else
        auto::orchestrator::trigger_immediate_rollback
    fi
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля автоматической настройки
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    i18n::load
    log_start
    log_info "Будет выполнена автоматическая установка базовых правил:"
    log_info_simple_tab "SSHD Установлен случайный SSH порт [10000-65535]"
    log_info_simple_tab "SSHD Запрет авторизации пользователя root"
    log_info_simple_tab "SSHD Запрет авторизации по паролю"
    log_info_simple_tab "UFW Отключен ping сервера [/etc/ufw/before.rules]"
    log_info_simple_tab "UFW Создано правило для вновь установленного SSH порта"
    log_info_simple_tab "UFW Активация"
    log_info "Будет активирован фоновый процесс rollback.sh для отката по истечению $ROLLBACK_TIMER_SECONDS секунд. В случае невозможности подключиться к серверу откатите изменения в текущем сеансе или дождитесь истечения таймера и подключайтесь к серверу по старым данным."
    log_info "Для просмотра логов используйте системный журнал [journalctl -t bsss --since \"10 minutes ago\"] или логи в каталоге установки $(readlink -f "${PROJECT_ROOT}/logs")"
    io::confirm_action
    auto::install::run
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
