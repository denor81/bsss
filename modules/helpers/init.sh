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
