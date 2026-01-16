#!/usr/bin/env bash
# ROLLBACK

set -Eeuo pipefail

readonly UTILS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${UTILS_DIR_PATH}/../lib/vars.conf"
source "${UTILS_DIR_PATH}/../lib/logging.sh"
source "${UTILS_DIR_PATH}/../lib/user_confirmation.sh"
source "${UTILS_DIR_PATH}/../modules/common-helpers.sh"
source "${UTILS_DIR_PATH}/../modules/04-ssh-port-helpers.sh"

SLEEP_PID=""

trap 'orchestrator::stop_rollback' SIGUSR1

# @type:        Orchestrator
# @description: Останавливает процесс отката
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::stop_rollback() {
    kill "$SLEEP_PID" 2>/dev/null
    log_stop 2>&3
    exit 0
}

# @type:        Orchestrator
# @description: Таймер для автоматического отката
# @params:
#   main_script_pid PID основного скрипта
#   watchdog_fifo FIFO для коммуникации
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::watchdog_timer() {
    local main_script_pid="$1"
    local watchdog_fifo="$2"
    # Используем анонимный дескриптор для вывода в FIFO,
    # переданный вторым аргументом $2
    exec 3<> "$watchdog_fifo"
    log_start 2>&3
    log_info "Фоновый таймер запущен на $ROLLBACK_TIMER_SECONDS сек..." 2>&3

    # Запускаю в фоне, что бы можно было в любой момент сбросить таймер
    # Иначе sleep блокирует выполнение до истечения
    sleep "$ROLLBACK_TIMER_SECONDS" &
    SLEEP_PID=$!

    # Теперь ожидаем процесс sleep - тут можно прервать выполнение сигналом USR1
    if wait "$SLEEP_PID" 2>/dev/null; then
        # Если sleep дожил до конца — рубим основной скрипт
        echo >&3
        log::draw_lite_border 2>&3
        log_info "Время истекло - выполняется ОТКАТ" 2>&3
        orchestrator::total_rollback 2>&3

        if kill -0 "$main_script_pid" 2>/dev/null; then
            kill -USR1 "$main_script_pid" 2>/dev/null || true
        fi
        
    fi
    # log_info ">> завершен [PID: $$]" 2>&3
    log_stop 2>&3
    exec 3>&-
    printf '%s\0' "$watchdog_fifo" | sys::delete_paths 2>/dev/null
}

# @type:        Orchestrator
# @description: Полная очистка системы от следов BSSS и деактивация UFW.
#               Вызывается при критическом сбое или таймауте.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::total_rollback() {
    log_warn "Инициирован полный демонтаж настроек ${UTIL_NAME^^}..."

    ssh::delete_all_bsss_rules 2>&3
    ufw::force_disable 2>&3
    ufw::delete_all_bsss_rules 2>&3
    orchestrator::actions_after_port_change 2>&3
    
    log_success "Система возвращена к исходному состоянию. Проверьте доступ по старым портам."
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      @ - параметры для watchdog_timer
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
main() {
    orchestrator::watchdog_timer "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi