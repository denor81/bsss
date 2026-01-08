#!/usr/bin/env bash
# Основной скрипт для последовательного запуска модулей системы
# Usage: run with ./local-runner.sh

set -Eeuo pipefail

# Константы
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MAIN_DIR_PATH}/lib/vars.conf"
source "${MAIN_DIR_PATH}/lib/logging.sh"
source "${MAIN_DIR_PATH}/lib/user_confirmation.sh"
source "${MAIN_DIR_PATH}/modules/common-helpers.sh"

# @type:        Orchestrator
# @description: Поиск и запуск модулей с типом 'check'
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @stderr:      нет
# @exit_code:   0 - модули найдены и все успешно выполнены
#               1 - в случае отсутствия модулей
#               2 - в случае ошибки одного из модулей
run_modules_polling() {
    local err=0
    local found=0

    log::draw_border
    while read -r -d '' m_path <&3; do
        found=$((found + 1))
        if ! bash "$m_path"; then
            err=1
        fi
    done 3< <(sys::get_paths_by_mask "${MAIN_DIR_PATH%/}/$MODULES_DIR" "$MODULES_MASK" \
    | sys::get_modules_paths_w_type \
    | sys::get_modules_by_type "$MODULE_TYPE_CHECK")

    (( found == 0 )) && { log_error "Запуск не возможен, Модули не найдены"; log::draw_border; return 1; }
    (( err > 0 )) && { log_error "Запуск не возможен, один из модулей показывает ошибку"; log::draw_border; return 2; }
    log::draw_border
}

# @type:        Orchestrator
# @description: Поиск и запуск модулей с типом 'modify'
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @stderr:      нет
# @exit_code:   0 - модули найдены и все успешно выполнены
#               return $? - проброс кода ошибки от модуля
run_modules_modify() {
    while read -r -d '' m_path <&3; do
        bash "$m_path" || return
    done 3< <(sys::get_paths_by_mask "${MAIN_DIR_PATH%/}/$MODULES_DIR" "$MODULES_MASK" \
    | sys::get_modules_paths_w_type \
    | sys::get_modules_by_type "$MODULE_TYPE_MODIFY")
}

main() {
    run_modules_polling
    io::confirm_action "Запустить настройку?"
    run_modules_modify
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
