# === SOURCE ===

# @type:        Source
# @description: Получает список пользователей системы
# @stdin:       нет
# @stdout:      username:password:uid:gid:gecos:home:shell\0
# @exit_code:   0 успешно
user::list::get() {
    gawk -F: '
        BEGIN { ORS="\0" }
        ($3 == 0) || ($3 >= 1000 && $3 != 65534 && $1 != "nobody")
    ' < /etc/passwd
}

# @type:        Source
# @description: Генерирует случайный пароль указанной длины
# @stdin:       нет
# @stdout:      password\n
# @exit_code:   0 успешно
#               1 openssl не найден
user::pass::generate() {
    local length="${1:-$BSSS_USER_PASS_LEN}"

    if ! command -v openssl >/dev/null 2>&1; then
        return 1
    fi

    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# === FILTER ===

# @type:        Validator
# @description: Проверяет, существует ли только root пользователь в системе
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 существует только root (uid: 0)
#               1 существует несколько пользователей (bsssuser не создан)
#               2 существует несколько пользователей (bsssuser создан)
#               3 существует только 1 пользователь, но uid не равен 0
user::system::is_only_root() {
    local usernames=()
    local uids=()
    local username pass uid rest
    local has_bsssuser=false

    while IFS=":" read -r -d '' username pass uid rest; do
        usernames+=("$username")
        uids+=("$uid")
        [[ "$username" == "$BSSS_USER_NAME" ]] && has_bsssuser=true
    done < <(user::list::get)

    local count=${#usernames[@]}

    if [[ "$count" -eq 1 ]]; then
        if [[ "${uids[0]}" -eq 0 ]]; then
            return 0
        else
            return 3
        fi
    fi

    if [[ "$count" -gt 1 ]]; then
        if [[ "$has_bsssuser" == "true" ]]; then
            return 2
        else
            return 1
        fi
    fi
}

# === VALIDATOR ===

# === SINK ===

# @type:        Sink
# @description: Отображает информацию о пользователях в системе
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
user::info::block() {
    local login_user=$(logname 2>/dev/null || echo "N/A")
    local auth_method=$(sys::user::get_auth_method | tr -d '\0')
    local i=0

    log_info "$(_ "common.info.users_in_system")"
    while IFS=":" read -r -d '' username pass uid rest; do
        i=$(( i + 1 ))

        local active_mark=""
        [[ "$username" == "$login_user" ]] && active_mark+="<<<$(_ "common.session.owner")|auth:${auth_method}"
        active_mark+="|"

        if [[ "$uid" -eq 0 ]]; then
            active_mark+="sudo:superuser"
        elif sudo -l -U "$username" 2>/dev/null | grep -Eq "NOPASSWD\:\s+ALL"; then
            active_mark+="sudo:nopass"
        elif id -nG "$username" | grep -qw "sudo"; then
            active_mark+="sudo:pass"
        else
            active_mark+="sudo:nosudo"
        fi

        log_info_simple_tab "${i}. ${username}|id:${uid}${active_mark}"
    done < <(user::list::get)
}

# @type:        Sink
# @description: Создает пользователя $BSSS_USER_NAME
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               $? ошибка useradd
user::create::execute() {
    useradd -m -d "/home/$BSSS_USER_NAME" -s /bin/bash -G sudo "$BSSS_USER_NAME" 2>&1
}

# @type:        Sink
# @description: Устанавливает пароль для пользователя
# @stdin:       username:password\0
# @stdout:      нет
# @exit_code:   0 успешно
#               1 отсутствует входные данные
#               $? ошибка chpasswd
user::pass::set() {
    local cred=""

    [[ ! -t 0 ]] && IFS= read -r -d '' cred || return 1

    echo "$cred" | chpasswd 2>&1
}

# @type:        Sink
# @description: Создает файл в /etc/sudoers.d/ для парольного доступа к sudo
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка создания файла или установки прав
user::sudoers::create_file() {
    local sudoers_file="${SUDOERS_D_DIR}/${BSSS_USER_NAME}"

    echo "${BSSS_USER_NAME} ALL=(ALL) NOPASSWD:ALL" | sudo tee "$sudoers_file" > /dev/null || return 1
    sudo chmod 0440 "$sudoers_file" || return 1
}
