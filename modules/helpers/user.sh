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
#               1 существует несколько пользователей (bsssuser не создан)
#               2 существует несколько пользователей (bsssuser создан)
#               3 существует только 1 пользователь, но uid не равен 0 (это не root) 
user::system::is_only_root() {
    local usernames=()
    local uids=()
    local username pass uid rest
    local has_bsssuser=false

    # Читаем данные из gawk (он выдает строки целиком, разделенные \0)
    # Нам нужно распарсить строку внутри цикла, чтобы достать UID
    while IFS=":" read -r -d '' username pass uid rest; do
        usernames+=("$username")
        uids+=("$uid")
        [[ "$username" == "$BSSS_USER_NAME" ]] && has_bsssuser=true
    done < <(user::list::get)

    local count=${#usernames[@]}

    # Сценарий: Только один пользователь
    if [[ "$count" -eq 1 ]]; then
        if [[ "${uids[0]}" -eq 0 ]]; then
            return 0  # Только root (uid: 0)
        else
            return 3  # Только 1 пользователь, но это не root (UID != 0)
        fi
    fi

    # Сценарий: Несколько пользователей
    if [[ "$count" -gt 1 ]]; then
        if [[ "$has_bsssuser" == "true" ]]; then
            return 2  # Несколько пользователей, bsssuser среди них есть
        else
            return 1  # Несколько пользователей, но bsssuser нет
        fi
    fi
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
        printf '%s\0' "key"
    elif [[ "$auth_info" == *"password"* ]] || [[ "$auth_info" == *"keyboard-interactive"* ]]; then
        printf '%s\0' "pass"
    else
        printf '%s\0' "n/a"
    fi
}

user::info::block() {
    local login_user=$(logname 2>/dev/null || echo "N/A")
    local auth_method=$(user::system::get_auth_method | tr -d '\0')
    local i=0

    log_info "Пользователи в системе:"
    # log_info "[superuser-root пользователь] [sudo:pass-пользователь в группе sudo с вводом пароля] [sudo:nopass-пользователь в группе sudo без необходимости ввода пароля] [nosudo-пользователь без sudo]"
    while IFS=":" read -r -d '' username pass uid rest; do
        i=$(( i + 1 ))

        local active_mark=""
        [[ "$username" == "$login_user" ]] && active_mark+="<<<session owner|auth:${auth_method}"
        active_mark+="|"

        if [[ "$uid" -eq 0 ]]; then
            active_mark+="sudo:superuser"
            # log_success "Пользователь $username имеет права sudo БЕЗ пароля."
        elif sudo -l -U "$username" 2>/dev/null | grep -Eq "NOPASSWD\:\s+ALL"; then
            active_mark+="sudo:nopass"
            # log_info "Пользователь $username в группе sudo (требуется пароль)."
        elif id -nG "$username" | grep -qw "sudo"; then
            active_mark+="sudo:pass"
            # log_info "Пользователь $username в группе sudo (требуется пароль)."
        else
            active_mark+="sudo:nosudo"
            # log_error "У пользователя $username НЕТ прав sudo!"
        fi

        log_info_simple_tab "${i}. ${username}|id:${uid}${active_mark}"
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
