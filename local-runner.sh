#!/usr/bin/env bash
# local-runner.sh
# Локальный загрузчик для запуска основного скрипта с конфигурацией
# Usage: ./local-runner.sh [options] [--uninstall]

set -Eeuox pipefail

# Константы
readonly SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CONFIG_FILE="${SCRIPT_DIR}/config/bsss.conf"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"
readonly MAIN_SCRIPT="${SCRIPT_DIR}/bsss-main.sh"

# Коды возврата
readonly SUCCESS=0
readonly ERR_CONFIG_NOT_FOUND=1
readonly ERR_MODULES_DIR_NOT_FOUND=2
readonly ERR_UNINSTALL_SCRIPT_NOT_FOUND=3

# Функции логирования
log_success() { echo "[v] $1"; }
log_error() { echo "[x] $1" >&2; }
log_info() { echo "[*] $1"; }

# Проверка и загрузка конфигурационного файла
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Конфигурационный файл не найден: $CONFIG_FILE"
        return "$ERR_CONFIG_NOT_FOUND"
    fi
    
    # Загрузка конфигурации
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    log_info "Конфигурация загружена из: $CONFIG_FILE"
    return "$SUCCESS"
}

# Обработка параметра --uninstall
handle_uninstall() {
    if [[ "$1" == "--uninstall" ]]; then
        local uninstall_script="${SCRIPT_DIR}/uninstall.sh"
        
        if [[ -f "$uninstall_script" ]]; then
            log_info "Запуск скрипта удаления"
            exec "$uninstall_script"
        else
            log_error "Скрипт удаления не найден: $uninstall_script"
            return "$ERR_UNINSTALL_SCRIPT_NOT_FOUND"
        fi
    fi
}

# DEBUG BREAKPOINT
exit 0

# Проверка наличия директории с модулями
check_modules_dir() {
    if [[ ! -d "$MODULES_DIR" ]]; then
        log_error "Директория с модулями не найдена: $MODULES_DIR"
        return "$ERR_MODULES_DIR_NOT_FOUND"
    fi
    log_info "Директория с модулями найдена: $MODULES_DIR"
}

# Установка переменной окружения для локальных модулей
setup_cache_base() {
    export CACHE_BASE="$MODULES_DIR"
    log_info "CACHE_BASE установлен в: $CACHE_BASE"
}

# Инициализация логирования для предотвращения ошибок
init_logging_minimal() {
    # Создаем минимальную функцию log_verbose если она еще не определена
    if ! declare -f log_verbose >/dev/null 2>&1; then
        log_verbose() {
            # Ничего не делаем в minimal режиме
            return 0
        }
    fi
}

# Запуск основного скрипта
run_main_script() {
    if [[ ! -f "$MAIN_SCRIPT" ]]; then
        log_error "Основной скрипт не найден: $MAIN_SCRIPT"
        return 1
    fi
    
    log_info "Запуск основного скрипта: $MAIN_SCRIPT"
    exec "$MAIN_SCRIPT" "$@"
}

# Основная функция
main() {
    # Обработка параметра --uninstall
    handle_uninstall "$@"
    
    # Загрузка конфигурации
    load_config
    
    # Проверка директории с модулями
    check_modules_dir
    
    # Настройка переменной окружения
    setup_cache_base
    
    # Запуск основного скрипта
    run_main_script "$@"
}

# Запуск основной функции
main "$@"