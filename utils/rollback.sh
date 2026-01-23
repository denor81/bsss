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
source "${UTILS_DIR_PATH}/../modules/05-ufw-helpers.sh"
source "${UTILS_DIR_PATH}/../modules/03-ssh-socket-helpers.sh"

SLEEP_PID=""
MAIN_SCRIPT=""
ROLLBACK_TYPE="${ROLLBACK_TYPE:-}"

trap 'log_stop 2>&3' EXIT
trap 'orchestrator::stop_rollback' SIGUSR1
trap 'orchestrator::immediate_rollback' SIGUSR2

# @type:        Orchestrator
# @description: Останавливает процесс таймера отката и завершает скрипт
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::stop_rollback() {
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
orchestrator::immediate_rollback() {
    kill "$SLEEP_PID" 2>/dev/null
    log::draw_lite_border 2>&3
    orchestrator::rollback 2>&3

    if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
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
orchestrator::ssh_rollback() {
    log_warn "Инициирован полный демонтаж настроек ${UTIL_NAME^^}..." 2>&3
    ssh::delete_all_bsss_rules 2>&3
    ufw::force_disable 2>&3
    ufw::delete_all_bsss_rules 2>&3
    orchestrator::actions_after_port_change 2>&3
    log_success "Система возвращена к исходному состоянию. Проверьте доступ по старым портам." 2>&3
}

# @type:        Orchestrator
# @description: Простой откат для UFW модуля - только отключение UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::ufw_rollback() {
    log_warn "Выполняется откат UFW..." 2>&3
    ufw::force_disable 2>&3
    orchestrator::actions_after_ufw_change 2>&3
    log_success "UFW отключен. Проверьте доступ к серверу." 2>&3
}

# @type:        Orchestrator
# @description: Откат SSH на socket режим
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::ssh_socket_rollback() {
    log_warn "Откат на socket-режим..." 2>&3
    ssh::switch_to_socket_mode 2>&3
    log_success "SSH возвращен в socket-режим" 2>&3
}

# @type:        Orchestrator
# @description: Полная очистка системы от следов BSSS и деактивация UFW.
#               Вызывается при критическом сбое или таймауте.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::rollback() {
    case "$ROLLBACK_TYPE" in
        "ssh") orchestrator::ssh_rollback ;;
        "ufw") orchestrator::ufw_rollback ;;
        "ssh_socket") orchestrator::ssh_socket_rollback ;;
        *) log_error "Неизвестный тип отката: $ROLLBACK_TYPE"; return 1 ;;
    esac
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
    MAIN_SCRIPT_PID="$1"
    local watchdog_fifo="$2"
    local timeout="${SSH_SOCKET_ROLLBACK_TIMER_SECONDS:-$ROLLBACK_TIMER_SECONDS}"
    exec 3> "$watchdog_fifo"
    log_start 2>&3
    log_info "Фоновый таймер запущен на $timeout сек..." 2>&3
    
    local rollback_message
    case "$ROLLBACK_TYPE" in
        "ssh")
            rollback_message="будут сброшены настройки ${UTIL_NAME^^} для SSH порта и отключен UFW"
            ;;
        "ufw")
            rollback_message="будет отключен UFW"
            ;;
        "ssh_socket")
            rollback_message="SSH будет возвращен в socket-режим"
            ;;
        *)
            rollback_message="будут сброшены настройки"
            ;;
    esac
    
    log_bold_info "По истечению таймера $rollback_message" 2>&3
    log_bold_info "В случае разрыва текущей сессии подключайтесь к серверу по старым параметрам после истечения таймера" 2>&3

    sleep "$timeout" &
    SLEEP_PID=$!

    if wait "$SLEEP_PID" 2>/dev/null; then
        log::new_line >&3
        log::draw_lite_border 2>&3
        log_info "Время истекло - выполняется ОТКАТ" 2>&3
        orchestrator::rollback 2>&3

        if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
            kill -USR1 "$MAIN_SCRIPT_PID" 2>/dev/null || true
            wait "$MAIN_SCRIPT_PID" 2>/dev/null || true
        fi
    fi
    log_stop 2>&3
    exec 3>&-
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