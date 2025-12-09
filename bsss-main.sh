#!/usr/bin/env bash
# bsss-main.sh
# Основной скрипт для последовательного запуска модулей системы
# Usage: ./bsss-main.sh

set -Eeuo pipefail

# Константы
readonly UTIL_NAME="bsss"
# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly MODULES_DIR="${THIS_DIR_PATH}/modules"
# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly CURRENT_MODULE_NAME="$(basename "$0")"


# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/lib/logging.sh"

hello() {
    log_info "Запуск основной системы ${UTIL_NAME^^}"
}

# Проверяет существование модуля
check_module_exists() {
    local module_name="$1"
    local module_path="${MODULES_DIR}/${module_name}"
    
    if [[ ! -f "$module_path" ]]; then
        log_error "Модуль не найден: $module_path"
        return 1
    fi
    
    return 0
}

# Запускает модуль в изолированном процессе
run_module() {
    local module_name="$1"
    local module_path="${MODULES_DIR}/${module_name}"
    
    log_info "Запуск модуля: $module_name"
    
    # Запускаем модуль в изолированном процессе через bash
    bash "$module_path"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Модуль $module_name выполнен успешно"
    else
        log_error "Модуль $module_name завершился с ошибкой (код: $exit_code)"
        return 1
    fi
    
    return 0
}

# Получает список всех доступных модулей
get_available_modules() {
    if [[ -d "$MODULES_DIR" ]]; then
        find "$MODULES_DIR" -name "*.sh" -type f | sort
    else
        log_error "Директория модулей не найдена: $MODULES_DIR"
        return 1
    fi
}

# Основная функция-стартер для запуска модулей
start_modules() {
    log_info "Начинаю последовательный запуск модулей..."
    
    local modules_list
    modules_list=$(get_available_modules) || {
        log_error "Ошибка при получении списка модулей"
        return 1
    }
    
    if [[ -z "$modules_list" ]]; then
        log_info "Модули для запуска не найдены"
        return 1
    fi
    
    local module_count=0
    local success_count=0
    
    while IFS= read -r module_path; do
        if [[ -n "$module_path" ]]; then
            local module_name
            module_name=$(basename "$module_path")
            
            module_count=$((module_count + 1))
            
            if check_module_exists "$module_name"; then
                if run_module "$module_name"; then
                    success_count=$((success_count + 1))
                else
                    log_error "Ошибка при выполнении модуля: $module_name"
                    # Продолжаем выполнение остальных модулей даже при ошибке
                fi
            fi
        fi
    done <<< "$modules_list"
    
    log_info "Завершено: $success_count из $module_count модулей выполнено успешно"
    
    return 0
}

# Основная функция
main() {
    start_modules
}

main
log_success "Завершен"
