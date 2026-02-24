# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Source
# @description: Находить последний префикс файла конфигурации permissions
#               Не учитывает bsss файлы по маске BSSS_PERMISSIONS_CONFIG_FILE_MASK
# @stdin:       нет
# @stdout:      prefix\0 (число) или пустая строка если файлов нет
# @exit_code:   0 префикс найден или файлов нет
permissions::config::find_last_prefix() {
    local file prefix="10"

    while IFS= read -r -d '' file; do
        if grep -qEi '^\s*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)\b' "$file"; then
            basename_file=$(basename "$file")
            prefix="${basename_file%%-*}"

            if [[ "$prefix" =~ ^[0-9]+$ ]]; then
                printf '%s' "$prefix"
                return 0
            fi
            printf '%s' "$prefix"
        fi
    done < <(sudo find "${SSH_CONFIGD_DIR}" -maxdepth 1 -type f -name "*.conf" ! -name "$BSSS_PERMISSIONS_CONFIG_FILE_MASK" -print0 | sort -z 2>/dev/null)
}

# === VALIDATOR ===

# @type:        Validator
# @description: Проверять наличие BSSS конфигурации permissions
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 конфигурация существует
#               1 конфигурация отсутствует
permissions::rules::is_configured() {
    compgen -G "${SSH_CONFIGD_DIR}/*${BSSS_PERMISSIONS_CONFIG_FILE_MASK}" >/dev/null
}

# === SINK ===

# @type:        Sink
# @description: Логировать все BSSS конфигурации permissions
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
permissions::log::bsss_configs() {
    local grep_result
    local found=0

    while IFS= read -r grep_result || break; do

        if (( found == 0 )); then
            log_info "$(_ "common.info.rules_found")"
            found=$((found + 1))
        fi

        log_info_simple_tab "$grep_result"

    # || true: grep возвращает код 1 если ничего не найдено - это нормальная ситуация
    done < <(grep -EiHs '^\s*(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin)\b' "${SSH_CONFIGD_DIR}/"$BSSS_PERMISSIONS_CONFIG_FILE_MASK || true)

    if (( found == 0 )); then
        log_info "$(_ "common.info.no_rules")"
    fi
}

# @type:        Sink
# @description: Логировать все сторонние конфигурации permissions
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
permissions::log::other_configs() {
    local grep_result
    local found=0

    while IFS= read -r grep_result || break; do

        if (( found == 0 )); then
            log_info "$(_ "common.info.external_rules_found")"
            found=$((found + 1))
        fi

        log_info_simple_tab "$grep_result"

    # || true: grep возвращает код 1 если ничего не найдено - это нормальная ситуация
    done < <(grep -EiHs --exclude="${SSH_CONFIGD_DIR}/"$BSSS_PERMISSIONS_CONFIG_FILE_MASK '^\s*(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin)\b' "${SSH_CONFIGD_DIR}/"$SSH_CONFIG_FILE_MASK "$SSH_CONFIG_FILE" || true)

    if (( found == 0 )); then
        log_info "$(_ "common.info.no_external_rules")"
    fi
}

# @type:        Sink
# @description: Отображать инструкции guard для пользователя
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
permissions::log::guard_instructions() {
    log_attention "$(_ "common.warning.dont_close_terminal")"
    log_attention "$(_ "permissions.guard.test_access")"
}

# @type:        Orchestrator
# @description: Создавать файл конфигурации SSH с настройками доступа
#               Отключает логин root и по паролю, включает вход по ключам
# @stdin:       нет
# @stdout:      path\0 к созданному файлу
# @exit_code:   0 файл создан успешно
#               1 ошибка создания файла
permissions::rules::make_bsss_rules() {
    local last_prefix new_prefix path

    last_prefix=$(permissions::config::find_last_prefix)

    if [[ -z "$last_prefix" ]]; then
        new_prefix="10"
    else
        printf -v new_prefix "%02d" $(( 10#$last_prefix - 1 ))
    fi

    path="${SSH_CONFIGD_DIR}/${new_prefix}${BSSS_PERMISSIONS_CONFIG_FILE_NAME}"

    if cat > "$path" << EOF
# $BSSS_MARKER_COMMENT
# User permissions
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
EOF
    then
        log_info "$(_ "common.file.created" "$path")"
    else
        log_error "$(_ "common.error.create_file" "$path")"
        return 1
    fi
}

# @type:        Sink
# @description: Удалять все BSSS конфигурации permissions
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 конфигурации успешно удалены или отсутствуют
permissions::rules::restore() {
    # || true: Ошибка допустима если файлов для удаления нет
    sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_PERMISSIONS_CONFIG_FILE_MASK" | sys::file::delete || true
}
