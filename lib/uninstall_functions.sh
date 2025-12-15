#!/usr/bin/env bash
# uninstall_functions.sh
# Библиотека функций для удаления установленных файлов и директорий
# Использование: source "$(dirname "${BASH_SOURCE[0]}")/../lib/uninstall_functions.sh"

# Адаптированная для тестирования функция удаления установленных файлов и директорий
# Параметризирована для удобного тестирования
_run_uninstall() {
    # Параметры функции с значениями по умолчанию
    local uninstall_paths="${1:-$UNINSTALL_PATHS}"  # Путь к файлу со списком путей для удаления
    local util_name="${2:-$UTIL_NAME}"  # Имя утилиты для вывода в сообщениях
    local current_module_name="${3:-$CURRENT_MODULE_NAME}"  # Имя текущего модуля
    local auto_confirm="${4:-false}"  # Автоматическое подтверждение (true/false)
    
    # Запрашиваем подтверждение удаления, если не указано авто-подтверждение
    if [[ "$auto_confirm" != "true" ]]; then
        read -p "$SYMBOL_QUESTION [$current_module_name] Выбрано удаление $util_name - подтвердите - y/n [n]: " -r confirmation
        confirmation=${confirmation:-n}
        
        if [[ ! ${confirmation,,} =~ ^[y]$ ]]; then
            log_info "Удаление отменено"
            return 0
        fi
    fi
    
    # Проверяем наличие файла с путями для удаления
    if [[ ! -f "$uninstall_paths" ]]; then
        log_error "Файл с путями для удаления не найден: $uninstall_paths"
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
    done < "$uninstall_paths"
    
    log_success "Удаление завершено успешно"
    return 0
}