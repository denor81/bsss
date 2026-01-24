#!/usr/bin/env bash
# ROLLBACK

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/common-helpers.sh"
source "${PROJECT_ROOT}/modules/04-ssh-port-helpers.sh"
source "${PROJECT_ROOT}/modules/05-ufw-helpers.sh"

MAIN_SCRIPT_PID=""
SLEEP_PID=""
MAIN_SCRIPT=""
ROLLBACK_TYPE="${ROLLBACK_TYPE:-}"

trap "" INT TERM
trap 'log_stop' EXIT
trap 'orchestrator::stop_rollback' SIGUSR1
trap 'rollback::orchestrator::immediate' SIGUSR2

# @type:        Orchestrator
# @description: Останавливает процесс таймера отката и завершает скрипт
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::stop() {
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
rollback::orchestrator::immediate() {
    kill "$SLEEP_PID" 2>/dev/null
    log::draw_lite_border
    orchestrator::rollback

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
rollback::orchestrator::ssh() {
    log_warn "Инициирован полный демонтаж настроек ${UTIL_NAME^^}..."
    ssh::delete_all_bsss_rules
    ufw::force_disable
    ufw::delete_all_bsss_rules
    ssh::orchestrator::actions_after_port_change
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
    ufw::force_disable
    ufw::orchestrator::actions_after_ufw_change
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
#   main_script_pid PID основного скрипта
#   watchdog_fifo FIFO для коммуникации
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::watchdog_timer() {
    MAIN_SCRIPT_PID="$1"
    local watchdog_fifo="$2"
    local timeout="$ROLLBACK_TIMER_SECONDS"

    exec 3> "$watchdog_fifo"

    mkdir -p "${PROJECT_ROOT}/logs"
    readonly ROLLBACK_LOG_FILE="${PROJECT_ROOT}/logs/rb_$(date +%Y-%m-%d_%H-%M-%S).log"
    exec > >(tee -a "$ROLLBACK_LOG_FILE" > "$watchdog_fifo") 2>&1

    log_start
    log_info "Фоновый таймер запущен на $timeout сек..."
    
    local rollback_message
    case "$ROLLBACK_TYPE" in
        "ssh") rollback_message="будут сброшены настройки ${UTIL_NAME^^} для SSH порта и отключен UFW" ;;
        "ufw") rollback_message="будет отключен UFW" ;;
        *) rollback_message="будут сброшены настройки" ;;
    esac
    
    log_bold_info "По истечению таймера $rollback_message"
    log_bold_info "В случае разрыва текущей сессии подключайтесь к серверу по старым параметрам после истечения таймера"

    sleep "$timeout" &
    SLEEP_PID=$!

    if wait "$SLEEP_PID" 2>/dev/null; then
        log::new_line
        log::draw_lite_border
        log_info "Время истекло - выполняется ОТКАТ"
        orchestrator::rollback

        if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
            kill -USR1 "$MAIN_SCRIPT_PID" 2>/dev/null || true
            wait "$MAIN_SCRIPT_PID" 2>/dev/null || true
        fi
    fi
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