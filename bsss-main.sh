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
    local raw_paths=""
    local -a available_paths=()

    raw_paths=$(_get_files_paths_by_mask "${MAIN_DIR_PATH}/modules" "$MODULES_MASK") || return 1

    if [[ -n "$raw_paths" ]]; then
        mapfile -t available_paths < <(printf '%s' "$raw_paths")
    fi

    if (( ${#available_paths[@]} == 0 )); then
        log_error "Модули не найдены, выполнение скрипта не возможно"
        return 1
    else
        awk -F': ' 'BEGIN { OFS="\t" } /^# MODULE_TYPE:/ { print FILENAME, $2; nextfile }' "${available_paths[@]}"
    fi
}

# Получает список модулей по типу
_get_modules_by_type() {
    local required_type="$1"
    local paths_w_types=""
    local -a matching_modules=()

    paths_w_types=$(_get_all_modules_with_types) || return 1

    if [[ -n "$paths_w_types" ]]; then
        while IFS=$'\t' read -r m_path m_type; do
            if [[ "$m_type" == "$required_type" ]]; then
                matching_modules+=("$m_path")
            fi
        done < <(printf '%s\n' "$paths_w_types")
    fi

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
    local check_modules=""
    local m_path=""

    check_modules=$(_get_modules_by_type "$MODULE_TYPE_CHECK") || return 1

    if [[ -n "$check_modules" ]]; then
        _draw_border
        while IFS= read -r m_path; do

            [[ -z "$m_path" ]] && continue
        
            if ! bash "$m_path"; then
                rc=1
            fi
            
        done < <(printf '%s\n' "$check_modules")
        _draw_border
    else
        log_error "Ни один модуль не найден, запуск не возможен"
        return 1
    fi

    if (( rc > 0 )); then
        log_error "Запуск не возможен, один из модулей показывает ошибку"
        return 1
    fi
}

user_choice() {
    # Запрашиваем подтверждение у пользователя
    local user_choice=""
    user_choice=$(_ask_user_confirmation "Запустить модули последовательно?" "Y" "yn" )
    
    if [[ "$user_choice" == "n" ]]; then
        log_info "Выход по запросу пользователя"
        exit 0
    fi
}

# Запускает change-модули с параметром -r
run_modules_modifying() {
    local modify_modules=""
    local m_path=""

    modify_modules=$(_get_modules_by_type "$MODULE_TYPE_MODIFY") || return 1
    
    if [[ -n "$modify_modules" ]]; then

        # Используем дескриптор 3, что бы освободить интерактивность с запущенным скриптом
        while IFS= read -r m_path <&3; do

            [[ -z "$m_path" ]] && continue

            log_info "Запуск $(basename "$m_path")"

            # Запускаем модуль напрямую, интерактивные запросы пойдут через /dev/tty
            if bash "$m_path"; then
                log_success "$(basename "$m_path") выполнен успешно"
            else
                log_error "Ошибка при выполнении $(basename "$m_path")"
                return 1
            fi

        done 3< <(printf '%s\n' "$modify_modules")

    else
        log_info "Не найдены модули для модификации"
    fi
    
    log_success "Все модули для изменений выполнены"
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
