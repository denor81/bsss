#!/usr/bin/env bash
# Проверяет операционную систему
# MODULE_ORDER: 10
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"

# @type:        Filter
# @description: Получает строку ID текущей системы
# @params:      нет
# @stdin:       content of a file (stream)
# @stdout:      string ID
# @exit_code:   0 - всегда
get_os_id() {
    gawk -F= '
        $1=="ID" {
            gsub (/"/, "", $2)
            print $2
            exit
        }
    '
}

# @type:        Orchestrator
# @description: Проверяет совместимость текущей ОС с разрешенной
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - система поддерживается
#               1 - ошибка валидации или файл не найден
check() {
    [[ -f "$OS_RELEASE_FILE_PATH" ]] || {
        log_error "os.check.file_not_found" "$OS_RELEASE_FILE_PATH"
        return 1
    }

    local id
    id=$( get_os_id < "$OS_RELEASE_FILE_PATH" )

    if [[ "$id" != "$ALLOWED_SYS" ]]; then
        log_error "os.check.unsupported" "${id^:-Unknown}" "$ALLOWED_SYS"
        return 1
    fi

    log_info "os.check.supported" "${id^}"
}

# @type:        Orchestrator
# @description: Точка входа модуля проверки ОС
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - проверка прошла успешно
#               1 - ошибка проверки
main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi