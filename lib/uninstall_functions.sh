#!/usr/bin/env bash
# uninstall_functions.sh
# Библиотека функций для удаления установленных файлов и директорий
# Использование: source "${PROJECT_ROOT}/lib/uninstall_functions.sh"

source "${PROJECT_ROOT}/lib/user_confirmation.sh"
UNINSTALL_FILE_PATH=$PROJECT_ROOT/$UNINSTALL_PATHS

# @type:        Filter
# @description: Проверяет наличие файла с путями для удаления
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - файл найден
#               1 - файл не найден
check_uninstall_file() {
    # Проверяем наличие файла с путями для удаления
    if [[ ! -f "$UNINSTALL_FILE_PATH" ]]; then
        log_error "Файл с путями для удаления не найден: $UNINSTALL_FILE_PATH"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Выполняет удаление файлов из файла лога
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка удаления
do_uninstall() {
    local path=""
    # Читаем файл построчно и удаляем каждый путь
    while IFS= read -r path || break; do
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
    done < "$UNINSTALL_FILE_PATH"
}


# @type:        Orchestrator
# @description: Запускает процесс удаления с подтверждением
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка удаления
run_uninstall() {
    io::confirm_action "Удалить ${UTIL_NAME^^}?"
    check_uninstall_file
    
    log_info "Начинаю удаление установленных файлов..."
    do_uninstall
    log_success "Удаление завершено успешно"
}