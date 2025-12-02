#!/usr/bin/env bash
# bsss-main.sh
# Основной скрипт для последовательного запуска модулей системы
# Usage: ./bsss-main.sh

set -Eeuo pipefail

# Константы
# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"

# Коды возврата
readonly SUCCESS=0
readonly ERR_MODULE_NOT_FOUND=1
readonly ERR_MODULE_EXECUTION=2
readonly ERR_GET_MODULES=3

readonly SYMBOL_SUCCESS="[V]"
readonly SYMBOL_QUESTION="[?]"
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[X]"

# Функции логирования
log_success() { echo "$SYMBOL_SUCCESS $1"; }
log_error() { echo "$SYMBOL_ERROR $1" >&2; }
log_info() { echo "$SYMBOL_INFO $1"; }

# Проверяет существование модуля
check_module_exists() {
    local module_name="$1"
    local module_path="${MODULES_DIR}/${module_name}"
    
    if [[ ! -f "$module_path" ]]; then
        log_error "Модуль не найден: $module_path"
        return "$ERR_MODULE_NOT_FOUND"
    fi
    
    return "$SUCCESS"
}

# Запускает модуль в изолированном процессе
run_module() {
    local module_name="$1"
    local module_path="${MODULES_DIR}/${module_name}"
    
    log_info "Запуск модуля: $module_name"
    
    # Запускаем модуль в изолированном процессе через bash
    bash "$module_path"
    local exit_code=$?
    
    if [[ $exit_code -eq $SUCCESS ]]; then
        log_success "Модуль $module_name выполнен успешно"
    else
        log_error "Модуль $module_name завершился с ошибкой (код: $exit_code)"
        return "$ERR_MODULE_EXECUTION"
    fi
    
    return "$SUCCESS"
}

# Получает список всех доступных модулей
get_available_modules() {
    if [[ -d "$MODULES_DIR" ]]; then
        find "$MODULES_DIR" -name "*.sh" -type f | sort
    else
        log_error "Директория модулей не найдена: $MODULES_DIR"
        return "$ERR_MODULE_NOT_FOUND"
    fi
}

# Основная функция-стартер для запуска модулей
start_modules() {
    log_info "Начинаю последовательный запуск модулей..."
    
    local modules_list
    modules_list=$(get_available_modules) || {
        log_error "Ошибка при получении списка модулей"
        return "$ERR_GET_MODULES"
    }
    
    if [[ -z "$modules_list" ]]; then
        log_info "Модули для запуска не найдены"
        return "$ERR_GET_MODULES"
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
    
    return "$SUCCESS"
}

# Основная функция
main() {
    log_info "Запуск основной системы BSSS"
    start_modules
    log_success "Работа системы завершена"
}

main "$@"