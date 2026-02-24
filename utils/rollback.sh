#!/usr/bin/env bash
# ROLLBACK

#
#
#
# LOG_STRICT_MODE нужен для маскировки ошибок логирования при экстренном прерывании родительского скрипта
# SIGPIPE гасим по той же причине - обеспечиваем максимальную живучесть rollback
#
#
#

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"

LOG_STRICT_MODE=false
MAIN_SCRIPT_PID=""
SLEEP_PID=""
ROLLBACK_TYPE=""

# На случай прерывания родительского скрипт защищаемся от SIGPIPE для максимальной устойчивости rollback
trap '' SIGPIPE # Игнорируем ошибки пайпов при записи логов в закрытый дескриптор

trap '' INT TERM # Игнорируем прерывание - скрипт должен жить
trap 'rollback::orchestrator::exit' EXIT
trap 'rollback::orchestrator::stop_usr1' SIGUSR1
trap 'rollback::orchestrator::immediate_usr2' SIGUSR2

# @type:        Orchestrator
# @description: Выполняет действия при завершении скрипта
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
rollback::orchestrator::exit() {
    log_info "$(_ "common.exit_received")"
    log_info "$(_ "rollback.close_redirection")"
    log_stop
    exec 3>&-
    exit 0
}

# @type:        Orchestrator
# @description: Останавливает процесс таймера отката и завершает скрипт
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
rollback::orchestrator::stop_usr1() {
    log_info "$(_ "rollback.stop_usr1_received")"
    kill "$SLEEP_PID" 2>/dev/null
    exit 0
}

# @type:        Orchestrator
# @description: Выполняет немедленный откат при получении SIGUSR2
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
rollback::orchestrator::immediate_usr2() {
    log_info "$(_ "rollback.immediate_usr2_received")"
    kill "$SLEEP_PID" 2>/dev/null
    rollback::dispatcher

    if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
        # || true: MAIN_SCRIPT_PID может завершиться до отправки сигнала
        log_info "$(_ "rollback.signal_usr1_sent")"
        kill -USR1 "$MAIN_SCRIPT_PID" 2>/dev/null || true
        # || true: Процесс может уже завершиться к моменту вызова wait
        wait "$MAIN_SCRIPT_PID" 2>/dev/null || true
    fi

    exit 0
}

# @type:        Orchestrator
# @description: Выполняет полный откат для SSH модуля
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 все команды выполнены успешно
#               1 одна или несколько команд завершились с ошибкой
rollback::orchestrator::ssh() {
    local errors=()
    log_warn "$(_ "rollback.ssh_dismantle")"

    ssh::rule::delete_all_bsss  || errors+=("ssh::rule::delete_all_bsss")
    ufw::rule::delete_all_bsss  || errors+=("ufw::rule::delete_all_bsss")
    ufw::status::force_disable  || errors+=("ufw::status::force_disable")
    ufw::ping::restore          || errors+=("ufw::ping::restore")
    sys::service::restart       || errors+=("sys::service::restart")
    
    log_actual_info
    ssh::orchestrator::log_statuses
    ufw::orchestrator::log_statuses

    if (( ${#errors[@]} == 0 )); then
        log_success "$(_ "rollback.system_restored")"
    else
        log_warn "$(_ "rollback.error.rollback_errors" "${errors[*]}")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Выполняет откат для UFW модуля
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 все команды выполнены успешно
#               1 одна или несколько команд завершились с ошибкой
rollback::orchestrator::ufw() {
    local errors=()
    log_warn "$(_ "rollback.ufw_dismantle")"

    ufw::status::force_disable  || errors+=("ufw::status::force_disable")
    ufw::ping::restore          || errors+=("ufw::ping::restore")
    
    log_actual_info
    ufw::orchestrator::log_statuses

    if (( ${#errors[@]} == 0 )); then
        log_success "$(_ "rollback.ufw_disabled")"
    else
        log_warn "$(_ "rollback.error.rollback_errors" "${errors[*]}")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Выполняет откат для permissions модуля
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 все команды выполнены успешно
#               1 одна или несколько команд завершились с ошибкой
rollback::orchestrator::permissions() {
    local errors=()
    log_warn "$(_ "rollback.permissions_dismantle")"

    permissions::rules::restore  || errors+=("permissions::rules::restore")
    sys::service::restart        || errors+=("sys::service::restart")

    log_actual_info
    permissions::log::bsss_configs
    permissions::log::other_configs

    if (( ${#errors[@]} == 0 )); then
        log_success "$(_ "rollback.permissions_restored")"
    else
        log_warn "$(_ "rollback.error.rollback_errors" "${errors[*]}")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Выполняет полный откат всех настроек BSSS
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
full_rollback::orchestrator::execute_all() {
    local errors=()

    # Выполняем команды. Если команда возвращает не 0, добавляем имя в массив.
    permissions::rules::restore || errors+=("permissions::rules::restore")
    ssh::rule::delete_all_bsss  || errors+=("ssh::rule::delete_all_bsss")
    ufw::rule::delete_all_bsss  || errors+=("ufw::rule::delete_all_bsss")
    ufw::status::force_disable  || errors+=("ufw::status::force_disable")
    ufw::ping::restore          || errors+=("ufw::ping::restore")
    sys::service::restart       || errors+=("sys::service::restart")

    # Проверка результатов
    if (( ${#errors[@]} == 0 )); then
        log_success "$(_ "rollback.system_restored")"
    else
        # Формируем сообщение об ошибках (через запятую)
        log_warn "$(_ "rollback.error.rollback_errors" "${errors[*]}")"
    fi
}

# @type:        Orchestrator
# @description: Выполняет полный откат всех настроек BSSS
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
rollback::orchestrator::full() {
    log_warn "$(_ "rollback.full_dismantle")"

    full_rollback::orchestrator::execute_all
}

# @type:        Orchestrator
# @description: Выполняет диспетчеризацию отката в зависимости от типа
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 откат выполнен успешно
#               1 неизвестный тип отката
rollback::dispatcher() {
    case "$ROLLBACK_TYPE" in
        "ssh") rollback::orchestrator::ssh ;;
        "ufw") rollback::orchestrator::ufw ;;
        "permissions") rollback::orchestrator::permissions ;;
        "full") rollback::orchestrator::full ;;
        *) log_error "$(_ "rollback.unknown_type" "$ROLLBACK_TYPE")"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Запускает таймер для автоматического отката
# @params:      rollback_type Тип отката (string\n)
#               main_script_pid PID основного скрипта (num\0)
#               watchdog_fifo FIFO для коммуникации (path)
#               sync_fifo FIFO для синхронизации (path)
#               quiet Режим без вывода (string\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
rollback::orchestrator::watchdog_timer() {
    ROLLBACK_TYPE="$1"
    MAIN_SCRIPT_PID="$2"
    local watchdog_fifo="$3"
    local sync_fifo="$4"
    local quiet="$5"
    
    exec 3> "$watchdog_fifo"

    log_start
    log_info "$(_ "rollback.redirection_opened" $$ "$(basename "$watchdog_fifo")")"

    if [[ $quiet != "quiet" ]]; then
    log_info "$(_ "rollback.timer_started" "$ROLLBACK_TIMER_SECONDS")"
        case "$ROLLBACK_TYPE" in
            "ssh") log_bold_info "$(_ "rollback.timeout_ssh")" ;;
            "ufw") log_bold_info "$(_ "rollback.timeout_ufw")" ;;
            "permissions") log_bold_info "$(_ "rollback.timeout_permissions")" ;;
            "full") log_bold_info "$(_ "rollback.timeout_generic")" ;;
            *) log_bold_info "$(_ "rollback.timeout_generic")" ;;
        esac
        log_bold_info "$(_ "rollback.timeout_reconnect")"
    fi

    sleep "$ROLLBACK_TIMER_SECONDS" &
    SLEEP_PID=$!

    # Rollback готов приимать сигналы - уведомляю главный скрипт
    printf '%s\n' "READY" > "$sync_fifo"

    if wait "$SLEEP_PID" 2>/dev/null; then
        new_line
        log_info "$(_ "rollback.time_expired")"
        rollback::dispatcher

        if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
            # || true: MAIN_SCRIPT_PID может завершиться до отправки сигнала
            log_info "$(_ "rollback.signal_usr1_sent")"
            kill -USR1 "$MAIN_SCRIPT_PID" 2>/dev/null || true
            # || true: Процесс может уже завершиться к моменту вызова wait
            wait "$MAIN_SCRIPT_PID" 2>/dev/null || true
        fi
    fi
}

# @type:        Orchestrator
# @description: Загружает переводы и запускает таймер
# @params:      args Аргументы для watchdog_timer (array\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
main() {
    i18n::load
    rollback::orchestrator::watchdog_timer "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi