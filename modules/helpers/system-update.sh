# Хелперы для модуля обновления системы

# === SOURCE ===

# @type:        Source
# @description: Генерирует команду обновления системы для apt
# @stdin:       нет
# @stdout:      command\0
# @exit_code:   0 успешно
#               1 apt не найден
sys::update::get_command() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "$(_ "system.update.apt_not_found")"
        return 1
    fi

    printf '%s\0' "apt-get update && apt-get upgrade -y"
}

# === SINK ===

# @type:        Sink
# @description: Выполняет обновление системы используя переданную команду
# @stdin:       command\0
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка выполнения команды
sys::update::execute() {
    local update_cmd=""
    [[ ! -t 0 ]] && IFS= read -r -d '' update_cmd || return 1

    if ! bash -c "$update_cmd" 1>&2; then
        log_error "$(_ "system.update.error")"
        return 1
    fi
}
