# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Filter
# @description: Извлекает ID операционной системы из потока
# @stdin:       content of /etc/os-release (text\n)
# @stdout:      os_id\n
# @exit_code:   0 успех
sys::get_os_id() {
    gawk -F= '
        $1=="ID" {
            gsub (/"/, "", $2)
            print $2
            exit
        }
    '
}

# @type:        Filter
# @description: Извлекает версию до точки
# @stdin:       content of /etc/os-release (text\n)
# @stdout:      version\n
# @exit_code:   0 успех
sys::get_os_ver() {
    gawk -F= '
        $1=="VERSION_ID" {
            gsub (/"/, "", $2)
            print $2
            exit
        }
    '
}

# @type:        Validator
# @description: Проверяет совместимость текущей ОС с разрешенной
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 система поддерживается
#               1 файл не найден или система не поддерживается
sys::id_and_ver_check() {
    [[ -f "$OS_RELEASE_FILE_PATH" ]] || {
        log_error "$(_ "os.check.file_not_found" "$OS_RELEASE_FILE_PATH")"
        return 1
    }

    local allowed_sys_id min_sys_ver current_id current_ver
    IFS="|" read -r allowed_sys_id min_sys_ver <<< "$ALLOWED_SYS"

    current_id=$( sys::get_os_id < "$OS_RELEASE_FILE_PATH" )
    current_ver=$( sys::get_os_ver < "$OS_RELEASE_FILE_PATH" )

    if [[ "$current_id" != "$allowed_sys_id" ]] || (( min_sys_ver > "${current_ver%%.*}" )); then
        log_error "$(_ "os.check.unsupported" "${current_id^:-Unknown} ${current_ver:-Unknown}" "$allowed_sys_id min version $min_sys_ver")"
        return 1
    fi

    log_info "$(_ "os.check.supported" "${current_id^} ${current_ver}")"
}