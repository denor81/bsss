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

# Получаю все модули с типом (разделитель \t)
_get_all_modules_with_types() {
    mapfile -t available_paths < <(_get_files_paths_by_mask "${MAIN_DIR_PATH}/modules" "$MODULES_MASK")
    awk -F': ' 'BEGIN { OFS="\t" } /^# MODULE_TYPE:/ { print FILENAME, $2; nextfile }' "${available_paths[@]}"
}

# Получает список модулей по типу
_get_modules_by_type() {
    local required_type="$1"
    declare -a matching_modules=()

    while IFS=$'\t' read -r m_path m_type; do
        if [[ "$m_type" == "$required_type" ]]; then
            matching_modules+=("$m_path")
        fi
    done < <(_get_all_modules_with_types)

    if (( ${#matching_modules[@]} > 0 )); then
        printf '%s\n' "${matching_modules[@]}"
    else
        log_error "Не найдены модули для редактирования конфигурации"
        return 1
    fi
}

_draw_border() {
    printf '%.0s#' {1..80}; echo
}

# Собирает экспресс-статус от всех модулей
run_modules_polling() {
    local rc=0

    _draw_border
    while IFS= read -r m_path; do
    
        if ! bash "$m_path"; then
            rc=1
        fi
        
    done < <(_get_modules_by_type "$MODULE_TYPE_CHECK")
    _draw_border

    if (( rc > 0 )); then
        log_error "Запуск не возможен, один из модулей показывает ошибку"
        return 1
    fi
}

user_choice() {
    # Запрашиваем подтверждение у пользователя
    local user_choice
    user_choice=$(_ask_user_confirmation "Запустить модули последовательно?" "Y" "yn" )
    
    if [[ "$user_choice" == "n" ]]; then
        log_info "Выход по запросу пользователя"
        exit 0
    fi
}

# Запускает change-модули с параметром -r
run_modules_modifying() {
    
    while IFS= read -r module_path; do

        log_info "Запуск $(basename "$module_path")"
        
        # Запускаем модуль напрямую, интерактивные запросы пойдут через /dev/tty
        if bash "$module_path"; then
            log_success "$(basename "$module_path") выполнен успешно"
        else
            log_error "Ошибка при выполнении $(basename "$module_path")"
            return 1
        fi

    done < <(_get_modules_by_type "$MODULE_TYPE_MODIFY")
    
    log_success "Все модули для изменений выполнены"
    return 0
}

# Основная функция
main() {
    run_modules_polling
    user_choice
    run_modules_modifying
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
