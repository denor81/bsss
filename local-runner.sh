#!/usr/bin/env bash
# local-runner.sh
# Локальный загрузчик для запуска основного скрипта с конфигурацией
# Usage: ./local-runner.sh [options] [--uninstall]

set -Eeuo pipefail

# Константы
# shellcheck disable=SC2155
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly MODULES_DIR_PATH="${MAIN_DIR_PATH}/modules"
readonly MAIN_SCRIPT_PATH="${MAIN_DIR_PATH}/bsss-main.sh"
readonly UNINSTALL_PATHS="/opt/bsss/.uninstall_paths"

# Коды возврата
readonly SUCCESS=0
readonly ERR_PARAM_PARSE=1

# Функции логирования
log_success() { echo -e "[v] $1"; }
log_error() { echo -e "[x] $1" >&2; }
log_info() { echo -e "[*] $1"; }

# Функция удаления установленных файлов и директорий
run_uninstall() {
    # Проверяем наличие файла с путями для удаления
    if [[ ! -f "$UNINSTALL_PATHS" ]]; then
        log_error "Файл с путями для удаления не найден: $UNINSTALL_PATHS"
        return 1
    fi
    
    log_info "Начинаю удаление установленных файлов..."
    
    # Читаем файл построчно и удаляем каждый путь
    while IFS= read -r path; do
        # Пропускаем пустые строки
        if [[ -z "$path" ]]; then
            continue
        fi
        
        # Проверяем существование пути или символической ссылки перед удалением
        if [[ -e "$path" || -L "$path" ]]; then
            log_info "Удаляю: $path"
            rm -rf "$path" || {
                log_error "Не удалось удалить: $path"
                return 1
            }
            log_success "Удалено: $path"
        else
            log_info "Путь не существует, пропускаю: $path"
        fi
    done < "$UNINSTALL_PATHS"
    
    log_success "Удаление завершено успешно"
    return 0
}

# Парсинг параметров запуска с использованием getopts
while getopts ":hu" opt; do
    case ${opt} in
        h)
            log_info "Использование: $0 [-h] [-u]"
            exit $SUCCESS
            ;;
        u)
            run_uninstall
            exit $?
            ;;
        \?)
            log_error "Неверный параметр: -$OPTARG"
            log_info "Использование: $0 [-h] [-u]"
            exit $ERR_PARAM_PARSE
            ;;
        :)
            log_error "Параметр -$OPTARG требует значение"
            exit $ERR_PARAM_PARSE
            ;;
    esac
done






# DEBUG BREAKPOINT
exit 0

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