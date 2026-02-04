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
        log_info "init.gawk.version"
        log_info_simple_tab "$(_ "init.gawk.installed" "$gawk_v")"
        return
    fi

    log_error "init.gawk.not_installed"
    log_info "init.gawk.nul_explanation"

    # Используем твой хелпер для подтверждения
    if io::confirm_action "init.gawk.install_confirm" || return; then
        if apt update && apt install gawk -y; then
            log_info "init.gawk.install_success"
        else
            local rc
            rc=$?
            log_error "init.gawk.install_error"
            return $rc
        fi
    fi
}
