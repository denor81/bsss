#!/usr/bin/env bash
# Проверяет операционную систему
# MODULE_TYPE: check

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"

# @type:        Filter
# @description: Получает строку ID текущей системы.
# @params:      нет.
# @stdin:       content of a file (stream)
# @stdout:      string ID
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
_get_os_id() {
    awk -F= '
        $1=="ID" {
            gsub (/"/, "", $2)
            print $2
            exit
        }
    '
}

# @type:        Validator
# @description: Проверяет совместимость текущей ОС с разрешенной.
# @params:      Использует глобальные readonly OS_RELEASE_FILE_PATH и ALLOWED_SYS.
# @stdin:       Не используется.
# @stdout:      Ничего.
# @stderr:      Диагностические сообщения (log_info, log_error).
# @exit_code:   0 — система поддерживается, 1 — ошибка валидации или файл не найден.
check() {
    [[ -f "$OS_RELEASE_FILE_PATH" ]] || { 
        log_error "Файл не существует: $OS_RELEASE_FILE_PATH"
        return 1
    }

    local id
    id=$( _get_os_id < "$OS_RELEASE_FILE_PATH" )

    if [[ "$id" != "$ALLOWED_SYS" ]]; then
        log_error "Система ${id^:-Unknown} не поддерживается (ожидалось: $ALLOWED_SYS)"
        return 1
    fi

    log_info "Система ${id^} поддерживается"
}

main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi