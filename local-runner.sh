#!/usr/bin/env bash
# local-runner.sh
# Локальный загрузчик для запуска основного скрипта с конфигурацией
# Usage: ./local-runner.sh [options] [--uninstall]

set -Eeuo pipefail

# Константы
readonly UTIL_NAME="bsss"
# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly UNINSTALL_PATHS="${THIS_DIR_PATH}/.uninstall_paths"
readonly RUN_PATH="${THIS_DIR_PATH}/bsss-main.sh"
readonly ALLOWED_PARAMS="hu"
# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly CURRENT_MODULE_NAME="$(basename "$0")"

UNINSTALL_FLAG=0
HELP_FLAG=0
RUN=0

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/lib/logging.sh"

# Запуск без параметров
if [ "$#" -eq 0 ]; then
    RUN=1
fi

log_info "Запуск"

# Парсинг параметров запуска с использованием getopts
# TESTED: tests/test_parse_params.sh
_parse_params() {
    # Всегда используем дефолтный ALLOWED_PARAMS
    local allowed_params="${1:-$ALLOWED_PARAMS}"
    
    # Сбрасываем OPTIND
    OPTIND=1
    
    while getopts ":$allowed_params" opt; do
        case "${opt}" in
            h)  HELP_FLAG=1 ;;
            u)  UNINSTALL_FLAG=1 ;;
            \?) log_info "Некорректный параметр -$OPTARG, доступны: $allowed_params" ;;
            :)  log_info "Параметр -$OPTARG требует значение" ;;
        esac
    done
}

# Функция удаления установленных файлов и директорий
run_uninstall() {
    # Запрашиваем подтверждение удаления
    read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] Выбрано удаление $UTIL_NAME - подтвердите - y/n [n]: " -r confirmation
    confirmation=${confirmation:-n}
    
    if [[ ! ${confirmation,,} =~ ^[y]$ ]]; then
        log_info "Удаление отменено"
        return 0
    fi
    
    # Проверяем наличие файла с путями для удаления
    if [[ ! -f "$UNINSTALL_PATHS" ]]; then
        log_error "Файл с путями для удаления не найден: $UNINSTALL_PATHS"
        return 1
    fi
    
    log_info "Начинаю удаление установленных файлов..."
    
    # Читаем файл построчно и удаляем каждый путь
    while IFS= read -r path; do
        # Проверяем существование пути или символической ссылки перед удалением
        if [[ -e "$path" || -L "$path" ]]; then
            log_info "Удаляю: $path"
            rm -rf "$path" || {
                log_error "Не удалось удалить: $path"
                return 1
            }
        else
            log_info "Путь не существует, пропускаю: $path"
        fi
    done < "$UNINSTALL_PATHS"
    
    log_success "Удаление завершено успешно"
    return 0
}

# Основная функция
main() {
    _parse_params "$ALLOWED_PARAMS" "$@"
    if [[ $UNINSTALL_FLAG -eq 1 ]]; then
        run_uninstall
    fi
    if [[ $HELP_FLAG -eq 1 ]]; then
        log_info "Доступны короткие параметры $ALLOWED_PARAMS, [-h помощь] [-u удаление]"
        return 0
    fi
    
    # Запускаем основной скрипт через exec, заменяя текущий процесс
    if [[ $RUN -eq 1 ]]; then
        if [[ -f "$RUN_PATH" ]]; then
            exec bash "$RUN_PATH"
        else
            log_error "Основной скрипт не найден: $RUN_PATH"
            return 1
        fi
    fi
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

log_success "Завершен"
