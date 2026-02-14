# @type:        Validator
# @description: Проверяет, есть ли правила UFW BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - есть хотя бы одно правило BSSS
#               1 - нет правил BSSS
ufw::rule::has_any_bsss() {
    ufw::rule::get_all_bsss | read -r -d '' _
}

# === SINK ===

# @type:        Sink
# @description: Создает бэкап файла before.rules
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - бэкап успешно создан
#               $? - код ошибки команды cp
ufw::ping::backup_file() {
    local res
    if res=$(cp -pv "$UFW_BEFORE_RULES" "$UFW_BEFORE_RULES_BACKUP" 2>&1); then
        log_info "$(_ "ufw.success.backup_created" "$res")"
    else
        local rc=$?
        log_error "$(_ "ufw.error.backup_failed" "$UFW_BEFORE_RULES_BACKUP" "$res")"
        return "$rc"
    fi
}

# @type:        Sink
# @description: Выполняет ufw reload для применения изменений
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки ufw reload
ufw::status::reload() {
    if ufw reload >/dev/null; then
        log_info "$(_ "ufw.success.reloaded")"
    else
        local rc=$?
        log_error "$(_ "ufw.error.reload_failed" "$rc")"
        return "$rc"
    fi
}
