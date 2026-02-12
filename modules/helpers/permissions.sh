# @type:        Source
# @description: Возвращает метод подключения пользователя [logname]
# @params:      нет
# @stdin:       нет
# @stdout:      connection_type\0 (PUBLICKEY/PASSWORD/UNKNOWN)
# @exit_code:   0
permissions::auth::get_method() {
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

# @type:        Source
# @description: Находит последний префикс файла, содержащего настройки SSH доступа
# @stdin:       нет
# @stdout:      prefix (число) или пустая строка если файлов нет
# @exit_code:   0
permissions::ssh::find_last_prefix() {
    local file path prefix max_prefix=""

    while IFS= read -r -d '' file; do
        [[ ! -f "$file" ]] && continue

        path="$file"
        
        if grep -qE '^\s*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)\b' "$path" 2>/dev/null; then
            basename_file=$(basename "$path")
            prefix="${basename_file%%-*}"
            
            if [[ "$prefix" =~ ^[0-9]+$ ]]; then
                [[ -z "$max_prefix" ]] || (( prefix > max_prefix )) && max_prefix="$prefix"
            fi
        fi
    done < <(find "${SSH_CONFIGD_DIR}" -maxdepth 1 -type f -name "*.conf" -print0 2>/dev/null)

    printf '%s' "$max_prefix"
}

# @type:        Sink
# @description: Логирует все BSSS конфигурации permissions с портами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
permissions::log::bsss_configs() {
    local grep_result
    local found=0

    while IFS= read -r grep_result || break; do

        if (( found == 0 )); then
            log_info "Есть правила ${UTIL_NAME^^} для доступа:"
            found=$((found + 1))
        fi

        log_info_simple_tab "$grep_result"

    done < <(grep -EiHs '^\s*(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin)\b' "${SSH_CONFIGD_DIR}/"$BSSS_PERMISSIONS_CONFIG_FILE_MASK || true)

    if (( found == 0 )); then
        log_info "Нет правил ${UTIL_NAME^^} для доступа"
    fi
}

# @type:        Sink
# @description: Логирует все сторонние конфигурации permissions с портами
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
permissions::log::other_configs() {
    local grep_result
    local found=0

    while IFS= read -r grep_result || break; do

        if (( found == 0 )); then
            log_info "Найдены сторонние правила для доступа"
            found=$((found + 1))
        fi

        log_info_simple_tab "$grep_result"

    done < <(grep -EiHs --exclude="${SSH_CONFIGD_DIR}/"$BSSS_PERMISSIONS_CONFIG_FILE_MASK '^\s*(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin)\b' "${SSH_CONFIGD_DIR}/"$SSH_CONFIG_FILE_MASK "$SSH_CONFIG_FILE" || true)

    if (( found == 0 )); then
        log_info "Нет стоонних правил для доступа"
    fi
}
