# @type:        Source
# @description: Проверяет наличие gawk и предлагает установку
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - gawk найден
#               1 - gawk не найден
#               2 - выход пользователя (io::confirm_action)
#               $? - иные ошибки
sys::gawk::check_dependency() {
    if command -v gawk >/dev/null 2>&1; then
        local gawk_v=$(gawk -V | head -n 1)
        log_info "$(_ "init.gawk.version")"
        log_info_simple_tab "$(_ "init.gawk.installed" "$gawk_v")"
        return 0
    fi

    log_error "$(_ "common.install.not_installed" "gawk")"
    log_info "$(_ "init.gawk.nul_explanation")"

    if io::confirm_action "$(_ "common.install.confirm" "gawk")" || return; then
        if apt-get update && apt-get install -y gawk; then
            log_info "$(_ "common.install.success" "gawk")"
        else
            local rc
            rc=$?
            log_error "$(_ "common.install.error" "gawk")"
            return $rc
        fi
    fi
}

# @type:        Sink
# @description: Вращает лог-файлы - удаляет старые файлы если их больше MAX_LOG_FILES
#               Если каталога не существует - ничего не делает
#               Если каталог существует, но нет логов - ничего не делает
#               Если файлов <= MAX_LOG_FILES - ничего не делает
#               Если файлов > MAX_LOG_FILES - удаляет самые ранние файлы по дате модификации
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
sys::log::rotate_old_files() {
    local logs_dir="${PROJECT_ROOT}/${LOGS_DIR}"
    [[ ! -d "$logs_dir" ]] && return 0
    
    find "$logs_dir" -maxdepth 1 -type f -name "[0-9][0-9][0-9][0-9]-*.log" -printf '%T@ %p\0' \
        | sort -z -n \
        | sed -z 's/^[0-9.]* //' \
        | head -z -n -"$MAX_LOG_FILES" \
        | xargs -r0 rm -f
}
