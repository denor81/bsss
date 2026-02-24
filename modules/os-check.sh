#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Проверяет операционную систему

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"

# @type:        Filter
# @description: Извлекает ID операционной системы из потока
# @stdin:       content of /etc/os-release (text\n)
# @stdout:      os_id\n
# @exit_code:   0 успех
get_os_id() {
    gawk -F= '
        $1=="ID" {
            gsub (/"/, "", $2)
            print $2
            exit
        }
    '
}

# @type:        Validator
# @description: Проверяет совместимость текущей ОС с разрешенной
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 система поддерживается
#               1 файл не найден или система не поддерживается
check() {
    [[ -f "$OS_RELEASE_FILE_PATH" ]] || {
        log_error "$(_ "os.check.file_not_found" "$OS_RELEASE_FILE_PATH")"
        return 1
    }

    local id
    id=$( get_os_id < "$OS_RELEASE_FILE_PATH" )

    if [[ "$id" != "$ALLOWED_SYS" ]]; then
        log_error "$(_ "os.check.unsupported" "${id^:-Unknown}" "$ALLOWED_SYS")"
        return 1
    fi

    log_info "$(_ "os.check.supported" "${id^}")"
}

# @type:        Orchestrator
# @description: Запускает модуль проверки ОС
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 проверка прошла успешно
#               1 ошибка проверки
main() {
    i18n::load
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi