#!/usr/bin/env bash
# Обновляет системные пакеты
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"
source "${MODULES_DIR_PATH}/../lib/user_confirmation.sh"
source "${MODULES_DIR_PATH}/common-helpers.sh"

# @type:        Source
# @description: Генерирует команду обновления системы для apt
# @params:      нет
# @stdin:       нет
# @stdout:      Команда обновления системы
# @exit_code:   0 - успешно
#               1 - apt не найден
sys::get_update_command() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "Менеджер пакетов apt-get не найден"
        return 1
    fi
    
    printf '%s\n' "apt-get update && apt-get upgrade -y"
}

# @type:        Sink
# @description: Выполняет обновление системы используя переданную команду
# @stdin:       Команда обновления системы
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка выполнения команды
sys::execute_update() {
    local update_cmd=""
    
    # Читаем команду из stdin
    [[ ! -t 0 ]] && IFS= read -r update_cmd || return 1
    
    if [[ -z "$update_cmd" ]]; then
        log_error "Получена пустая команда обновления"
        return 1
    fi
    
    log_info "Обновление системных пакетов..."
    
    # Выполняем команду без eval
    if bash -c "$update_cmd"; then
        log_success "Системные пакеты успешно обновлены"
        return 0
    else
        log_error "Ошибка при обновлении системных пакетов"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Оркестратор процесса обновления системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка обновления
sys::update_system() {
    log_info "Используется менеджер пакетов: apt"
    
    sys::get_update_command | sys::execute_update
}

# @type:        Orchestrator
# @description: Основная точка входа модуля обновления системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
main() {
    log_info ">> запущен модуль обновления системы [PID: $$]"
    
    if io::confirm_action "Обновить системные пакеты?"; then
        if sys::update_system; then
            log_info ">> модуль обновления системы завершен [PID: $$]"
        else
            log_error ">> модуль обновления системы завершен с ошибкой [PID: $$]"
            return 1
        fi
    else
        log_info "Обновление системных пакетов отменено"
        log_info ">> модуль обновления системы завершен [PID: $$]"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi