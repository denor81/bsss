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

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"

LOG_STRICT_MODE=false
MAIN_SCRIPT_PID=""
SLEEP_PID=""
MAIN_SCRIPT=""
ROLLBACK_TYPE=""

# На случай прерывания родительского скрипт защищаемся от SIGPIPE для максимальной устойчивости rollback
trap '' SIGPIPE # Игнорируем ошибки пайпов при записи логов в закрытый дескриптор

trap '' INT TERM # Игнорируем прерывание - скрипт должен жить
trap 'rollback::orchestrator::exit' EXIT
trap 'rollback::orchestrator::stop_usr1' SIGUSR1
trap 'rollback::orchestrator::immediate_usr2' SIGUSR2

# @type:        Orchestrator
# @description: Действия при завершении скрипта
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::exit() {
    log_info "Получен сигнал EXIT"
    log_info "Закрываем перенаправление 2>FIFO>parent_script"
    log_stop
    exec 2>&-
    exit 0
}

# @type:        Orchestrator
# @description: Останавливает процесс таймера отката и завершает скрипт
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::stop_usr1() {
    log_info "Получен сигнал USR1 - остановка таймера отката"
    kill "$SLEEP_PID" 2>/dev/null
    exit 0
}

# @type:        Orchestrator
# @description: Немедленно выполняет тотальный откат при получении SIGUSR2
#               Вызывается, когда порт не поднялся после изменения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::immediate_usr2() {
    log_info "Получен сигнал USR2 - остановка таймера отката и немедленный откат изменений"
    kill "$SLEEP_PID" 2>/dev/null
    rollback::orchestrator::full

    if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
        log_info "Посылаем сигнал отката основному скрипту USR1 [PID: $MAIN_SCRIPT_PID]"
        kill -USR1 "$MAIN_SCRIPT_PID" 2>/dev/null || true
        wait "$MAIN_SCRIPT_PID" 2>/dev/null || true
    fi

    exit 0
}

# @type:        Orchestrator
# @description: Полный откат для SSH модуля - сброс правил SSH и отключение UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::ssh() {
    log_warn "Инициирован полный демонтаж настроек ${UTIL_NAME^^}..."

    ssh::rule::delete_all_bsss
    ufw::rule::delete_all_bsss
    ufw::status::force_disable

    sys::service::restart
    log_actual_info
    ssh::orchestrator::log_statuses
    ufw::orchestrator::log_statuses

    log_success "Система возвращена к исходному состоянию. Проверьте доступ по старым портам."
}

# @type:        Orchestrator
# @description: Простой откат для UFW модуля - только отключение UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::ufw() {
    log_warn "Выполняется откат UFW..."

    ufw::status::force_disable
    log_actual_info
    ufw::orchestrator::log_statuses

    log_success "UFW отключен. Проверьте доступ к серверу."
}

# @type:        Orchestrator
# @description: Полная очистка системы от следов BSSS и деактивация UFW.
#               Вызывается при критическом сбое или таймауте.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::full() {
    case "$ROLLBACK_TYPE" in
        "ssh") rollback::orchestrator::ssh ;;
        "ufw") rollback::orchestrator::ufw ;;
        *) log_error "Неизвестный тип отката: $ROLLBACK_TYPE"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Таймер для автоматического отката
# @params:
#   rollback_type Тип отката (ssh/ufw)
#   main_script_pid PID основного скрипта
#   watchdog_fifo FIFO для коммуникации
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::watchdog_timer() {
    ROLLBACK_TYPE="$1"
    MAIN_SCRIPT_PID="$2"
    local watchdog_fifo="$3"

    exec 2> "$watchdog_fifo"
    log_start
    log_info "Открыто перенаправление 2>FIFO>parent_script"
    log_info "Фоновый таймер запущен на $ROLLBACK_TIMER_SECONDS сек..."
    
    local rollback_message
    case "$ROLLBACK_TYPE" in
        "ssh") rollback_message="будут сброшены настройки ${UTIL_NAME^^} для SSH порта и отключен UFW" ;;
        "ufw") rollback_message="будет отключен UFW" ;;
        *) rollback_message="будут сброшены настройки" ;;
    esac
    
    log_bold_info "По истечению таймера $rollback_message"
    log_bold_info "В случае разрыва текущей сессии подключайтесь к серверу по старым параметрам после истечения таймера"

    sleep "$ROLLBACK_TIMER_SECONDS" &
    SLEEP_PID=$!

    if wait "$SLEEP_PID" 2>/dev/null; then
        new_line
        log_info "Время истекло - выполняется ОТКАТ"
        rollback::orchestrator::full

        if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
            log_info "Посылаем сигнал отката основному скрипту USR1 [PID: $MAIN_SCRIPT_PID]"
            kill -USR1 "$MAIN_SCRIPT_PID" 2>/dev/null || true
            wait "$MAIN_SCRIPT_PID" 2>/dev/null || true
        fi
    fi
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      @ - параметры для watchdog_timer
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
main() {
    rollback::orchestrator::watchdog_timer "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi