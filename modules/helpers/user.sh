# @type:        Source
# @description: Получает список пользователей через NUL-разделитель
# @params:      нет
# @stdin:       нет
# @stdout:      line\0 | nothing
# @exit_code:   0 - успешно
user::list::get() {
    gawk -F: '
        BEGIN { ORS="\0" }
        ($3 == 0) || ($3 >= 1000 && $3 != 65534 && $1 != "nobody")
    ' < /etc/passwd
}

# @type:        Filter
# @description: Существует только root или нет (uid: 0)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 существует только root (uid: 0)
#               1 существует несколько пользователей
#               2 существует только 1 пользователь, но uid не равен 0 (это не root) 
user::system::is_only_root() {
    local lines=()
    local line

    while read -r -d '' line; do
        lines+=("$line")
    done < <(user::list::get)

    if [[ "${#lines[@]}" -eq 1 ]]; then
        if (( id == 0 )); then
            return 0  # существует только root (uid: 0)
        else
            return 2  # существует только 1 пользователь, но uid не равен 0 (это не root) 
        fi
    fi

    return 1 # существует несколько пользователей
}

# @type:        Source
# @description: Возвращает метод подключения пользователя [logname]
# @params:      нет
# @stdin:       нет
# @stdout:      connection_type\0 (PUBLICKEY/PASSWORD/UNKNOWN)
# @exit_code:   0
user::system::get_auth_method() {
    local auth_info

    auth_info=$(journalctl _COMM=sshd --since "12h ago" 2>/dev/null | grep "Accepted" | grep "for $(logname)" | tail -1)

    [[ -z "$auth_info" ]] && { printf '%s\0' "UNKNOWN"; return; }

    if [[ "$auth_info" == *"publickey"* ]]; then
        printf '%s\0' "PUBLICKEY"
    elif [[ "$auth_info" == *"password"* ]] || [[ "$auth_info" == *"keyboard-interactive"* ]]; then
        printf '%s\0' "PASSWORD"
    else
        printf '%s\0' "UNKNOWN"
    fi
}

user::info::block() {
    local login_user=$(logname 2>/dev/null || echo "N/A")
    local auth_method=$(user::system::get_auth_method | tr -d '\0')
    local i=0

    if user::system::is_only_root; then
        log_info "В системе только один пользователь root [UID: 0]"
        return 0
    fi

    log_info "В системе несколько пользователей:"
    while IFS=":" read -r -d '' username pass uid rest; do
        i=$(( i + 1 ))

        local active_mark=""
        [[ "$username" == "$login_user" ]] && active_mark+=" [ORIGIN] [${auth_method}]"

        log_info_simple_tab "${i}. ${username}:${pass}:${uid}:${rest}${active_mark}"
    done < <(user::list::get)
}

# @type:        Source
# @description: Генерирует случайный пароль указанной длины
# @params:
#   length      Длина пароля (по умолчанию $BSSS_USER_PASS_LEN)
# @stdin:       нет
# @stdout:      password
# @exit_code:   0 - успешно
#               1 - openssl не найден
user::pass::generate() {
    local length="${1:-$BSSS_USER_PASS_LEN}"

    if ! command -v openssl >/dev/null 2>&1; then
        return 1
    fi

    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# @type:        Sink
# @description: Создает пользователя $BSSS_USER_NAME
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка useradd
user::create::execute() {
    useradd -m -d "/home/$BSSS_USER_NAME" -s /bin/bash -G sudo "$BSSS_USER_NAME" 2>&1
}

# @type:        Sink
# @description: Устанавливает пароль для пользователя
#               Принимает поток "username:password"
# @stdin:       username:password\0
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка chpasswd
user::pass::set() {
    local cred=""

    [[ ! -t 0 ]] && IFS= read -r -d '' cred || return 1

    echo "$cred" | chpasswd 2>&1
}

# @type:        Sink
# @description: Надо придумать
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
user::log::configs() {
    local grep_result
    local found=0

    while IFS= read -r grep_result || break; do

        if (( found == 0 )); then
            log_info "Найдены правила настроек доступа"
            found=$((found + 1))
        fi

        log_info_simple_tab "$(_ "no_translate" "$grep_result")"

    done < <(grep -EiHs '^\s*(PubkeyAuthentication|PasswordAuthentication|PubkeyAuthentication)\b' "${SSH_CONFIGD_DIR}/"$SSH_CONFIG_FILE_MASK "$SSH_CONFIG_FILE" || true)

    if (( found == 0 )); then
        log_info "Активные правила не найдены [PubkeyAuthentication|PasswordAuthentication|PubkeyAuthentication]"
    fi
}
