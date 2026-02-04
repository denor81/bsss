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
        log_error "common.error_uninstall_file_not_found" "$UNINSTALL_FILE_PATH"
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
            log_info "common.info_uninstall_delete" "$path"
            rm -rf "$path" || {
                log_error "common.error_uninstall_delete_failed" "$path"
                return 1
            }
        else
            log_info "common.info_uninstall_path_not_exists" "$path"
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
    io::confirm_action "common.info_uninstall_confirm"
    check_uninstall_file
    
    log_info "common.info_uninstall_start"
    do_uninstall
    log_success "common.info_uninstall_success"
}