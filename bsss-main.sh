#!/usr/bin/env bash
# bsss-main.sh
# Основной скрипт для последовательного запуска модулей системы
# Usage: ./bsss-main.sh

set -Eeuo pipefail

# Константы
# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly MODULES_DIR="${THIS_DIR_PATH}/modules"
# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly CURRENT_MODULE_NAME="$(basename "$0")"


# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/lib/logging.sh"

# Получает список всех доступных модулей
get_available_modules() {
    if [[ -d "$MODULES_DIR" ]]; then
        # Ищем все исполняемые файлы, включая .sh и без расширения
        find "$MODULES_DIR" -type f \( -name "[0-9][0-9]*.sh" -o -executable \) | sort
    else
        log_error "Директория модулей не найдена: $MODULES_DIR"
        return 1
    fi
}

# Получает тип модуля из метаданных
get_module_type() {
    local module_path="${1:-}"
    if [[ -z "$module_path" || ! -f "$module_path" ]]; then
        echo "check-only"  # По умолчанию
        return 1
    fi
    
    # Ищем строку с MODULE_TYPE
    local module_type
    module_type=$(grep "^# MODULE_TYPE:" "$module_path" 2>/dev/null | cut -d: -f2 | tr -d ' ')
    
    # Если не найдено, считаем check-only
    if [[ -z "$module_type" ]]; then
        echo "check-only"
    else
        echo "$module_type"
    fi
}

# Получает список модулей по типу
get_modules_by_type() {
    local required_type="${1:-check-only}"
    local modules=()
    
    while IFS= read -r module_path; do
        if [[ -n "$module_path" ]]; then
            local module_type
            module_type=$(get_module_type "$module_path")
            
            if [[ "$module_type" == "$required_type" ]]; then
                modules+=("$module_path")
            fi
        fi
    done <<< "$(get_available_modules)"
    
    printf '%s\n' "${modules[@]}"
}

# Собирает экспресс-статус от всех модулей
collect_modules_status() {
    local critycal=0
    printf '%.0s#' {1..80}; echo
    while IFS= read -r module_path; do
        if [[ -n "$module_path" ]]; then

            out="$(bash "$module_path")"

            # Ожидаем от модуля message, symbol, status
            eval "$out"

            decoded_message=$(echo "$message" | base64 --decode)
            decoded_symbol=$(echo "$symbol" | base64 --decode)

            if [[ $status -eq 1 ]]; then
                critycal=1
            fi
            
            echo "# $decoded_symbol $(basename "$module_path"): $decoded_message"
        fi
    done <<< "$(get_available_modules)" || return 1
    printf '%.0s#' {1..80}; echo

    if [[ $critycal -eq 1 ]]; then
        log_error "Запуск не возможен, один из модулей показывает ошибку"
        return 1
    fi
}

# Запрашивает подтверждение у пользователя
ask_user_confirmation() {
    local choice
    
    while true; do
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] Запустить модули последовательно? (Y/n): " -r choice
        choice=${choice:-Y}  # Y по умолчанию
        
        if [[ ${choice,,} =~ ^[yn]$ ]]; then
            echo "${choice,,}"
            return 0
        fi
        
        log_error "Некорректный выбор. Введите Y или n"
    done
}

# Запускает change-модули с параметром -r
run_change_modules() {
    local change_modules
    change_modules=$(get_modules_by_type "check-and-run")
    
    if [[ -z "$change_modules" ]]; then
        log_info "Модули для изменений не найдены"
        return 0
    fi
    
    # log_info "Запуск модулей для изменений..."
    
    while IFS= read -r module_path; do
        if [[ -n "$module_path" ]]; then
            log_info "Запуск $(basename "$module_path")"
            
            # Запускаем модуль напрямую, интерактивные запросы пойдут через /dev/tty
            if bash "$module_path" -r; then
                log_success "$(basename "$module_path") выполнен успешно"
            else
                log_error "Ошибка при выполнении $(basename "$module_path")"
                return 1
            fi
        fi
    done <<< "$change_modules"
    
    log_success "Все модули для изменений выполнены"
    return 0
}

# Основная функция
main() {
    # Сначала экспресс-анализ всех модулей
    collect_modules_status
    
    # Запрашиваем подтверждение у пользователя
    local user_choice
    user_choice=$(ask_user_confirmation)
    
    if [[ "$user_choice" == "n" ]]; then
        log_info "Выход по запросу пользователя"
        return 0
    fi
    
    # Запускаем change-модули
    run_change_modules
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
