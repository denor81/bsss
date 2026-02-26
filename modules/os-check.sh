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

# @type:        Filter
# @description: Извлекает версию до точки
# @stdin:       content of /etc/os-release (text\n)
# @stdout:      version\n
# @exit_code:   0 успех
get_os_ver() {
    gawk -F= '
        $1=="VERSION_ID" {
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

    local allowed_sys_id min_sys_ver current_id current_ver
    IFS="|" read -r allowed_sys_id min_sys_ver <<< "$ALLOWED_SYS"

    current_id=$( get_os_id < "$OS_RELEASE_FILE_PATH" )
    current_ver=$( get_os_ver < "$OS_RELEASE_FILE_PATH" )

    if [[ "$current_id" != "$allowed_sys_id" ]] || (( min_sys_ver > "${current_ver%%.*}" )); then
        log_error "$(_ "os.check.unsupported" "${current_id^:-Unknown}" "$allowed_sys_id min version $min_sys_ver")"
        return 1
    fi

    log_info "$(_ "os.check.supported" "${current_id^} ${current_ver}")"
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