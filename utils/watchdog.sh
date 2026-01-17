#!/usr/bin/env bash
# WATCHDOG - Универсальный сторожевой таймер для опасных операций
# Использование: запуск с параметрами
# Параметры: <main_pid> <watchdog_fifo> <rollback_type>
#   rollback_type: ufw|full

set -Eeuo pipefail

readonly UTILS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${UTILS_DIR_PATH}/../lib/vars.conf"
source "${UTILS_DIR_PATH}/../lib/logging.sh"
source "${UTILS_DIR_PATH}/../modules/common-helpers.sh"

SLEEP_PID=""
WATCHDOG_FIFO=""
MAIN_PID=""
ROLLBACK_TYPE=""

# @type:        Orchestrator
# @description: Останавливает процесс сторожевого таймера
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::stop_watchdog() {
    if [[ -n "$SLEEP_PID" ]] && kill -0 "$SLEEP_PID" 2>/dev/null; then
        kill "$SLEEP_PID" 2>/dev/null || true
    fi
    log_stop 2>&3
    exit 0
}

# @type:        Orchestrator
# @description: Вызывает rollback.sh для выполнения отката
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::execute_rollback() {
    local rollback_script="${UTILS_DIR_PATH}/rollback.sh"
    
    # Вызываем rollback.sh с типом отката
    # Перенаправляем вывод в дескриптор 3 (FIFO)
    if [[ -f "$rollback_script" ]]; then
        bash "$rollback_script" "$ROLLBACK_TYPE" 2>&3 || true
    else
        log_error "Скрипт отката не найден: $rollback_script" 2>&3
    fi
}

# @type:        Orchestrator
# @description: Таймер для автоматического отката
# @params:
#   main_pid        PID основного скрипта
#   watchdog_fifo   FIFO для коммуникации
#   rollback_type   Тип отката: ufw|full
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::watchdog_timer() {
    MAIN_PID="$1"
    WATCHDOG_FIFO="$2"
    ROLLBACK_TYPE="$3"

    # Валидация параметров
    if [[ -z "$MAIN_PID" ]] || [[ -z "$WATCHDOG_FIFO" ]] || [[ -z "$ROLLBACK_TYPE" ]]; then
        log_error "Неверные параметры watchdog: main_pid=$MAIN_PID, fifo=$WATCHDOG_FIFO, type=$ROLLBACK_TYPE" 2>&3
        return 1
    fi

    # Проверка типа отката
    if [[ "$ROLLBACK_TYPE" != "ufw" ]] && [[ "$ROLLBACK_TYPE" != "full" ]]; then
        log_error "Неизвестный тип отката: [$ROLLBACK_TYPE]. Допустимые значения: ufw, full" 2>&3
        return 1
    fi

    # Открываем FIFO для записи и чтения (анонимный дескриптор 3)
    # Используем <> для чтения и записи, чтобы избежать блокировки
    exec 3<>"$WATCHDOG_FIFO"
    
    # Перенаправляем логирование в дескриптор 3 (в FIFO)
    log_start 2>&3
    
    case "$ROLLBACK_TYPE" in
        ufw)
            log_info "Фоновый таймер UFW запущен на $ROLLBACK_TIMER_SECONDS сек..." 2>&3
            log_bold_info "По истечению таймера будет выполнен откат UFW" 2>&3
            ;;
        full)
            log_info "Фоновый таймер запущен на $ROLLBACK_TIMER_SECONDS сек..." 2>&3
            log_bold_info "По истечению таймера будут сброшены настройки ${UTIL_NAME^^} для SSH порта и отключен UFW" 2>&3
            log_bold_info "В случае разрыва текущей сессии подключайтесь к серверу по старым портам после истечения таймера" 2>&3
            ;;
    esac

    # Запускаем sleep в фоне, чтобы можно было прервать выполнение сигналом USR1
    # Используем & для запуска в фоне и сохраняем PID
    sleep "$ROLLBACK_TIMER_SECONDS" &
    SLEEP_PID=$!

    # Ожидаем процесс sleep - здесь можно прервать выполнение сигналом USR1
    if wait "$SLEEP_PID" 2>/dev/null; then
        # Если sleep дожил до конца — выполняем откат
        echo >&3
        log::draw_lite_border 2>&3
        log_info "Время истекло - выполняется ОТКАТ" 2>&3
        orchestrator::execute_rollback 2>&3

        # Отправляем сигнал USR1 основному скрипту, если он еще жив
        if kill -0 "$MAIN_PID" 2>/dev/null; then
            kill -USR1 "$MAIN_PID" 2>/dev/null || true
        fi
    fi

    # Закрываем дескриптор 3 и удаляем FIFO
    log_stop 2>&3
    exec 3>&-
    printf '%s\0' "$WATCHDOG_FIFO" | sys::delete_paths 2>/dev/null
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      @ - параметры для watchdog_timer
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
main() {
    trap 'orchestrator::stop_watchdog' SIGUSR1
    orchestrator::watchdog_timer "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
