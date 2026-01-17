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

trap log_stop EXIT

# @type:        Source
# @description: Генерирует команду обновления системы для apt
# @params:      нет
# @stdin:       нет
# @stdout:      command\0
# @exit_code:   0 - успешно
#               1 - apt не найден
sys::get_update_command() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "Менеджер пакетов apt-get не найден"
        return 1
    fi
    
    printf '%s\0' "apt-get update && apt-get upgrade -y"
}

# @type:        Sink
# @description: Выполняет обновление системы используя переданную команду
# @stdin:       command\0
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка выполнения команды
sys::execute_update() {
    local update_cmd=""
    [[ ! -t 0 ]] && IFS= read -r -d '' update_cmd || return 1
    
    if ! bash -c "$update_cmd"; then
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
    log_start
    
    # Запуск или возврат кода 2 при отказе пользователя
    if io::confirm_action "Обновить системные пакеты? [apt-get update && apt-get upgrade -y]"; then
        sys::update_system
    else
        return
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi