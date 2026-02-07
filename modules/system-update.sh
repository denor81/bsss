#!/usr/bin/env bash
# Обновляет системные пакеты
# MODULE_ORDER: 20
# MODULE_TYPE: modify
# MODULE_NAME: module.system.update.name

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"

trap log_stop EXIT

# @type:        Source
# @description: Генерирует команду обновления системы для apt
# @params:      нет
# @stdin:       нет
# @stdout:      command\0
# @exit_code:   0 - успешно
#               1 - apt не найден
sys::update::get_command() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "$(_ "system.update.apt_not_found")"
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
sys::update::execute() {
    local update_cmd=""
    [[ ! -t 0 ]] && IFS= read -r -d '' update_cmd || return 1

    if ! bash -c "$update_cmd"; then
        log_error "$(_ "system.update.error")"
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
sys::update::orchestrator() {
    sys::update::get_command | sys::update::execute
}

# @type:        Orchestrator
# @description: Основная точка входа модуля обновления системы
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отказ пользователя (io::confirm_action)
#               $? - код ошибки дочернего процесса
main() {
    i18n::load
    log_start
    
    # Запуск или возврат кода 2 при отказе пользователя
    if io::confirm_action "$(_ "system.update.confirm")"; then
        sys::update::orchestrator
    else
        return
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi