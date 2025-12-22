#!/usr/bin/env bash
# uninstall_functions.sh
# Библиотека функций для удаления установленных файлов и директорий
# Использование: source "${MAIN_DIR_PATH}/lib/uninstall_functions.sh"

source "${MAIN_DIR_PATH}/lib/user_confirmation.sh"
UNINSTALL_FILE_PATH=$MAIN_DIR_PATH/$UNINSTALL_PATHS

check_uninstall_file() {
    # Проверяем наличие файла с путями для удаления
    if [[ ! -f "$UNINSTALL_FILE_PATH" ]]; then
        log_error "Файл с путями для удаления не найден: $UNINSTALL_FILE_PATH"
        return 1
    fi
}

do_uninstall() {
    local path=""
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
    done < "$UNINSTALL_FILE_PATH"
}


_run_uninstall() {
    _confirm_action "Удалить ${UTIL_NAME^^}?" "Удаление отменено пользователем" "N" || return "$?"
    check_uninstall_file
    
    log_info "Начинаю удаление установленных файлов..."
    do_uninstall
    log_success "Удаление завершено успешно"
}