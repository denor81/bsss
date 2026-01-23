#!/usr/bin/env bash
# Проверяет режим запуска SSH (socket vs service)
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/03-ssh-socket-helpers.sh"
source "${PROJECT_ROOT}/modules/common-helpers.sh"

WATCHDOG_FIFO="$PROJECT_ROOT/bsss_watchdog_$$.fifo"

trap stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Проверяет режим запуска SSH и переключает на service если нужно
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - режим корректен или успешно переключен
#               1 - отказ от переключения (strict mode, выполнение невозможно)
check() {
    if ssh::is_socket_mode; then
        log_error "SSH работает в режиме socket-активации"
        log_warn "Этот режим может вызывать проблемы с поднятием портов после изменения конфигурации"
        
        if io::confirm_action "Переключиться на классический режим ssh.service?"; then
            if orchestrator::switch_to_service_with_guard; then
                log_success "SSH успешно переключен на режим service"
                return 0
            else
                log_error "Ошибка при переключении режима SSH"
                return 1
            fi
        else
            log_error "Отказ от переключения режима. Выполнение невозможно."
            return 1
        fi
    else
        log_info "SSH работает в классическом режиме (service)"
        return 0
    fi
}

# @type:        Orchestrator
# @description: Создает FIFO и запускает слушатель для коммуникации с rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
make_fifo_and_start_reader() {
    mkfifo "$WATCHDOG_FIFO"
    log::new_line
    log_info "Создан FIFO: $WATCHDOG_FIFO"
    cat "$WATCHDOG_FIFO" >&2 &
}

# @type:        Orchestrator
# @description: Обработчик сигнала SIGUSR1 - останавливает скрипт при откате
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   3 - код завершения при откате
stop_script_by_rollback_timer() {
    printf '%s\0' "$WATCHDOG_FIFO" | sys::delete_paths
    exit 3
}

# @type:        Orchestrator
# @description: Запускает фоновый процесс rollback (watchdog)
# @params:      watchdog_fifo - путь к FIFO для коммуникации
# @stdin:       нет
# @stdout:      PID процесса watchdog
# @exit_code:   0 - успешно
orchestrator::watchdog_start() {
    local rollback_module="${PROJECT_ROOT}/${UTILS_DIR}/$ROLLBACK_MODULE_NAME"
    ROLLBACK_TYPE="ssh_socket" nohup bash "$rollback_module" "$$" "$WATCHDOG_FIFO" >/dev/null 2>&1 &
    printf '%s' "$!"
}

# @type:        Orchestrator
# @description: Останавливает процесс rollback (watchdog) по PID
# @params:      watchdog_pid - PID процесса watchdog для остановки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
orchestrator::watchdog_stop() {
    local watchdog_pid="$1"
    kill -USR1 "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    log_info "Изменения зафиксированы, Rollback отключен"
    printf '%s\0' "$WATCHDOG_FIFO" | sys::delete_paths
}

# @type:        Sink
# @description: Отображает инструкции пользователю для проверки подключения
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
orchestrator::guard_ui_instructions() {
    log::draw_lite_border
    log_attention "НЕ ЗАКРЫВАЙТЕ ЭТО ОКНО ТЕРМИНАЛА"
    log_attention "ОТКРОЙТЕ НОВОЕ ОКНО и проверьте связь"
}

# @type:        Orchestrator
# @description: Переключает SSH на service с механизмом отката
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка при переключении или валидации
orchestrator::switch_to_service_with_guard() {
    local watchdog_pid

    if ! sys::validate_sshd_config; then
        log_error "Конфигурация sshd содержит ошибки"
        log_info "Исправьте конфигурацию и запустите проверку снова"
        return 1
    fi

    make_fifo_and_start_reader

    watchdog_pid=$(orchestrator::watchdog_start "$WATCHDOG_FIFO")

    orchestrator::guard_ui_instructions

    if ! ssh::switch_to_service_mode; then
        kill -USR2 "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true
        return 1
    fi

    if ! ssh::is_service_mode; then
        log_error "SSH service не запустился"
        kill -USR2 "$watchdog_pid" 2>/dev/null || true
        wait "$watchdog_pid" 2>/dev/null || true
        while true; do sleep 1; done
    fi

    if io::ask_value "Подтвердите подключение - введите connected" "" "^connected$" "connected" >/dev/null; then
        orchestrator::watchdog_stop "$watchdog_pid"
    fi
}

main() {
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
