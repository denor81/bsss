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

    log_error "$(_ "init.gawk.not_installed")"
    log_info "$(_ "init.gawk.nul_explanation")"

    if io::confirm_action "$(_ "init.gawk.install_confirm")" || return; then
        if apt update && apt install gawk -y; then
            log_info "$(_ "init.gawk.install_success")"
        else
            local rc
            rc=$?
            log_error "$(_ "init.gawk.install_error")"
            return $rc
        fi
    fi
}
