#!/usr/bin/env bash
# ROLLBACK

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/common-helpers.sh"
source "${PROJECT_ROOT}/modules/04-ssh-port-helpers.sh"
source "${PROJECT_ROOT}/modules/05-ufw-helpers.sh"

MAIN_SCRIPT_PID=""
SLEEP_PID=""
MAIN_SCRIPT=""
ROLLBACK_TYPE=""

trap "" INT TERM # Попытка игнорировать прерывания ctrl c, но надо тестировать
trap 'log_stop' EXIT
trap 'rollback::orchestrator::stop' SIGUSR1
trap 'rollback::orchestrator::immediate' SIGUSR2

# @type:        Orchestrator
# @description: Останавливает процесс таймера отката и завершает скрипт
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
rollback::orchestrator::stop() {
    log_info "Получен сигнал USR1 - остановка таймера отката"
    log_info_simple_tab "Остановка таймера отката"
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
    log_info "Получен сигнал USR2 - немедленный откат изменений"
    log_info_simple_tab "Остановка таймера отката"
    kill "$SLEEP_PID" 2>/dev/null
    log::draw_lite_border
    rollback::orchestrator::full

    if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
        log_info_simple_tab "Посылаем сигнал отката основному скрипту USR1 [PID: $MAIN_SCRIPT_PID]"
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
    ufw::status::force_disable
    ufw::rule::delete_all_bsss
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
    ufw::status::force_disable
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

    exec 3> "$watchdog_fifo"

    mkdir -p "${PROJECT_ROOT}/logs"
    readonly ROLLBACK_LOG_FILE="${PROJECT_ROOT}/logs/rb_$(date +%Y-%m-%d_%H-%M-%S).log"
    exec > >(tee -a "$ROLLBACK_LOG_FILE" > "$watchdog_fifo") 2>&1

    log_start
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
        log::new_line
        log::draw_lite_border
        log_info "Время истекло - выполняется ОТКАТ"
        rollback::orchestrator::full

        if kill -0 "$MAIN_SCRIPT_PID" 2>/dev/null; then
            log_info "Посылаем сигнал отката основному скрипту USR1 [PID: $MAIN_SCRIPT_PID]"
            kill -USR1 "$MAIN_SCRIPT_PID" 2>/dev/null || true
            wait "$MAIN_SCRIPT_PID" 2>/dev/null || true
        fi
    fi
    log_info "Закрываем FIFO дескриптор 3"
    exec 3>&-
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