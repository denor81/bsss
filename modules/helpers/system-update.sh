# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Source
# @description: Генерирует команду обновления системы для apt
# @params:      mode Режим auto для обновления без вопросов (string) без завершающего символа, опционально
# @stdin:       нет
# @stdout:      command\0
# @exit_code:   0 успешно
#               1 apt не найден
sys::update::get_command() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "$(_ "system.update.apt_not_found")"
        return 1
    fi

    if [[ "${1:-}" == "auto" ]]; then
        printf '%s\0' "apt-get update && DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade --with-new-pkgs -y"
    else
        printf '%s\0' "apt-get update && apt-get upgrade --with-new-pkgs -y"
    fi
}

# @type:        Sink
# @description: Выполняет обновление системы используя переданную команду
# @stdin:       command\0
#               Package commands read directly from /dev/tty.
# @stdout:      нет
#               Package command output goes directly to /dev/tty.
# @exit_code:   0 успешно
#               1 ошибка выполнения команды
sys::update::execute() {
    local update_cmd=""
    [[ ! -t 0 ]] && IFS= read -r -d '' update_cmd || return 1

    if ! io::command::run_terminal bash -c "$update_cmd"; then
        log_error "$(_ "system.update.error")"
        return 1
    fi
}
