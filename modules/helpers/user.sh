# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

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
# @description: Генерирует случайный hex-пароль указанной длины
# @params:      length Длина пароля (num\n)
# @stdin:       нет
# @stdout:      password\n
# @exit_code:   0 успешно
#               1 openssl не найден
user::pass::generate() {
    local length="${1:-$BSSS_USER_PASS_LEN}"

    if ! command -v openssl >/dev/null 2>&1; then
        return 1
    fi

    openssl rand -hex "$(((length + 1) / 2))" | cut -c1-"$length"
}

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

# @type:        Filter
# @description: Summarizes authentication and cache settings from a verbose sudo listing
# @stdin:       LC_ALL=C sudo -ll output (line\n, 0..N)
# @stdout:      sudo:mode|sudocache:value\0
# @exit_code:   0 recognized listing
#               1 unsupported or incomplete listing
#               $? parsing failure
user::sudo::parse_status() {
    gawk '
        BEGIN { RS=""; ORS="\0"; cache="default"; authenticate=1; mode="nosudo" }

        # Parse comma-separated settings without treating quoted values as options.
        function options(text, scope,    fields, count, i, option, value, scoped_cache, scoped_authenticate) {
            count = patsplit(text, fields, /([^,"\\]|\\.|"([^"\\]|\\.)*")+/)
            for (i = 1; i <= count; i++) {
                option = fields[i]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", option)
                if (option == "!timestamp_timeout") option = "timestamp_timeout=0"
                if (option ~ /^timestamp_timeout[[:space:]]*=/) {
                    sub(/^[^=]*=[[:space:]]*/, "", option)
                    gsub(/^"|"$/, "", option)
                    if (option !~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/) {
                        invalid = 1
                        continue
                    }
                    value = option + 0
                    value = value < 0 ? "unlimited" : (value == 0 ? "no" : value "m")
                    if (scope == "defaults") cache = value
                    else if (scope == "entry") entry_cache = value
                    else scoped_cache = value
                } else if (option == "authenticate" || option == "!authenticate") {
                    value = option == "authenticate"
                    if (scope == "defaults") authenticate = value
                    else if (scope == "entry") entry_auth = value
                    else scoped_authenticate = value
                }
            }
            if (scope == "scoped") {
                if (scoped_cache != "" && scoped_cache != cache) mixed = 1
                if (scoped_authenticate != "" && scoped_authenticate != authenticate) scoped_auth = 1
            }
        }

        /^Matching Defaults entries for / {
            sub(/^[^\n]*\n/, "")
            options($0, "defaults")
            next
        }
        /^Runas and Command-specific defaults for / {
            count = split($0, lines, "\n")
            settings = ""
            for (i = 2; i <= count; i++) {
                if (lines[i] ~ /^[ \t]*Defaults[!>]/) {
                    options(settings, "scoped")
                    settings = lines[i]
                    sub(/^[ \t]*Defaults[!>]([^, \t\\]|\\.)+([ \t]*,[ \t]*([^, \t\\]|\\.)+)*[ \t]+/, "", settings)
                } else settings = settings "\n" lines[i]
            }
            options(settings, "scoped")
            next
        }
        /^(Sudoers entry|LDAP Role):/ {
            entry_auth = authenticate
            entry_cache = cache
            count = split($0, lines, "\n")
            settings = ""
            section = ""
            for (i = 2; i <= count; i++) {
                line = lines[i]
                if (line ~ /^[ \t]+Options:/) {
                    sub(/^[ \t]+Options:[ \t]*/, "", line)
                    settings = line
                    section = "options"
                } else if (line ~ /^[ \t]+Commands:/) {
                    options(settings, "entry")
                    section = "commands"
                } else if (line ~ /^[ \t]+[[:alpha:]]+:/ && section != "commands") {
                    section = ""
                } else if (section == "options") {
                    settings = settings "\n" line
                } else if (section == "commands") {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                    if (line == "") continue
                    recognized = 1
                    if (line == "!ALL") mode = "nosudo"
                    else if (line !~ /^!/) {
                        if (line == "ALL" || mode == "nosudo" || entry_auth)
                            mode = entry_auth ? "pass" : "nopass"
                        if (entry_cache != cache) mixed = 1
                    }
                }
            }
            next
        }
        /^User [^[:space:]]+ is not allowed to run sudo on / {
            recognized = 1
            mode = "nosudo"
        }
        END {
            if (invalid || !recognized) exit 1
            if (mode == "nosudo" || (mode == "nopass" && !scoped_auth)) cache = "n/a"
            else if (mixed || scoped_auth) cache = "mixed"
            print "sudo:" mode "|sudocache:" cache
        }
    '
}

# @type:        Source
# @description: Lists the user policy once and streams it to the sudo status parser
# @params:      username Account name (string), without terminator
# @stdin:       None
# @stdout:      sudo:mode|sudocache:value\0
# @exit_code:   0 status obtained
#               $? sudo or parsing failure
user::sudo::get_status() {
    LC_ALL=C sudo -n -ll -U "$1" | user::sudo::parse_status
}

# @type:        Sink
# @description: Отображает информацию о пользователях в системе
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
user::info::block() {
    local login_user=$(logname 2>/dev/null || echo "N/A")
    local auth_method=$(sys::user::get_auth_method | tr -d '\0')
    local i=0
    local sudo_status

    if user::system::is_only_root; then
        log_warn "$(_ "common.info.users_in_system")"
    else
        log_info "$(_ "common.info.users_in_system")"
    fi
    while IFS=":" read -r -d '' username pass uid rest; do
        i=$(( i + 1 ))

        local active_mark=""
        [[ "$username" == "$login_user" ]] && active_mark+="<<<$(_ "common.session.owner")|auth:${auth_method}"
        active_mark+="|"

        if [[ "$uid" -eq 0 ]]; then
            active_mark+="sudo:superuser"
        elif [[ "$username" == "$BSSS_USER_NAME" ]]; then
            sudo_status=$(user::sudo::get_status "$username" | tr -d '\0')
            active_mark+="$sudo_status"
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
# @description: Создает файл в /etc/sudoers.d/ с выбранным режимом доступа к sudo
# @params:      sudo_mode Режим sudo: PASSWD или NOPASSWD (string) без завершающего символа
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка создания файла или установки прав
user::sudoers::create_file() {
    local sudoers_file="${SUDOERS_D_DIR}/${BSSS_USER_NAME}"

    {
        if [[ "$1" == "PASSWD" ]]; then
            printf 'Defaults:%s timestamp_type=global, timestamp_timeout=30\n' "$BSSS_USER_NAME"
        fi
        printf '%s ALL=(ALL) %s:ALL\n' "$BSSS_USER_NAME" "$1"
    } | sudo tee "$sudoers_file" > /dev/null || return 1
    chmod 0440 "$sudoers_file" || return 1
}
