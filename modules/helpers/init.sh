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
        log_info "Ключевые зависимости:"
        log_info_simple_tab "gawk установлен [$gawk_v]"
        return
    fi

    log_error "Критическая зависимость - 'gawk' не установлен"
    log_info "Этот проект использует NUL-разделители, которые корректно поддерживает только GNU Awk"

    # Используем твой хелпер для подтверждения
    if io::confirm_action "Установить gawk сейчас? [apt update && apt install gawk -y]" || return; then
        if apt update && apt install gawk -y; then
            log_info "gawk успешно установлен"
        else
            local rc
            rc=$?
            log_error "Ошибка при установке gawk"
            return $rc
        fi
    fi
}
