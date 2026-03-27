# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Проверяет наличие BSSS конфигурации для отключения IPv6
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 конфигурация существует (IPv6 отключен)
#               1 конфигурация отсутствует (IPv6 включен)
ipv6::config::is_configured() {
    compgen -G "${GRUB_CONFIGD_DIR}/${BSSS_IPV6_GRUB_FILE_MASK}" >/dev/null
}

# @type:        Source
# @description: Находит последний числовой префикс в grub.d
# @stdin:       нет
# @stdout:      prefix (число) или пустая строка
# @exit_code:   0 всегда
ipv6::config::find_last_prefix() {
    local file
    local max_prefix=""

    [[ -d "$GRUB_CONFIGD_DIR" ]] || return 0

    while IFS= read -r -d '' file; do
        local basename_file prefix
        basename_file=$(basename "$file")
        prefix=${basename_file%%-*}

        if [[ "$prefix" =~ ^[0-9]+$ ]]; then
            if [[ -z "$max_prefix" || $((10#$prefix)) -gt $((10#$max_prefix)) ]]; then
                max_prefix="$prefix"
            fi
        fi
    done < <(find "$GRUB_CONFIGD_DIR" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)

    [[ -n "$max_prefix" ]] && printf '%s' "$max_prefix" || true
}

# @type:        Source
# @description: Генерирует следующий числовой префикс для файла в grub.d
# @stdin:       нет
# @stdout:      prefix (число)
# @exit_code:   0 всегда
ipv6::config::next_prefix() {
    local last_prefix
    local next_prefix

    last_prefix=$(ipv6::config::find_last_prefix)
    if [[ -z "$last_prefix" ]]; then
        next_prefix=50
    else
        next_prefix=$((10#$last_prefix + 1))
    fi

    printf '%02d' "$next_prefix"
}

# @type:        Orchestrator
# @description: Создает файл конфигурации для отключения IPv6
# @stdin:       нет
# @stdout:      path\0
# @exit_code:   0 файл создан
#               1 ошибка создания
ipv6::config::create_bsss_file() {
    local prefix path
    prefix=$(ipv6::config::next_prefix)
    path="${GRUB_CONFIGD_DIR}/${prefix}${BSSS_IPV6_GRUB_FILE_NAME}"

    mkdir -p "$(dirname "$path")" && chmod 755 "$(dirname "$path")"

    if cat > "$path" << EOF
# $BSSS_MARKER_COMMENT
GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT ipv6.disable=1"
EOF
    then
        chmod 644 "$path"
        log_info "$(_ "ipv6.info.config_created" "$path")"
        ipv6::config::update_grub || return 1
        printf '%s\0' "$path"
    else
        log_error "$(_ "common.error.create_file" "$path")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Обновляет grub после изменений конфигурации IPv6
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
ipv6::config::update_grub() {
    log_info "$(_ "common.log_command" "update-grub")"
    local res
    if ! res=$(update-grub 2>&1); then
        log_error "$(_ "ipv6.error.update_grub_failed" "${res:-update-grub}")"
        return 1
    fi
}

# @type:        Sink
# @description: Удаляет BSSS конфигурации IPv6
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
ipv6::config::remove_bsss_files() {
    if ! ipv6::config::is_configured; then
        return 0
    fi

    sys::file::get_paths_by_mask "$GRUB_CONFIGD_DIR" "$BSSS_IPV6_GRUB_FILE_MASK" | sys::file::delete || true
    ipv6::config::update_grub || return 1
}

# @type:        Orchestrator
# @description: Создает маркер перезагрузки и дополняет .pkgs
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка записи
ipv6::reboot::mark_required() {
    local pkgs_file="${REBOOT_REQUIRED_FILE_PATH}.pkgs"

    if [[ ! -f "$REBOOT_REQUIRED_FILE_PATH" ]]; then
        if ! touch "$REBOOT_REQUIRED_FILE_PATH"; then
            log_error "$(_ "common.error.create_file" "$REBOOT_REQUIRED_FILE_PATH")"
            return 1
        fi
        log_info "$(_ "ipv6.info.reboot_required" "$REBOOT_REQUIRED_FILE_PATH")"
    fi

    if [[ ! -f "$pkgs_file" ]]; then
        if ! touch "$pkgs_file"; then
            log_error "$(_ "common.error.create_file" "$pkgs_file")"
            return 1
        fi
    fi

    if ! grep -Fxq "$BSSS_IPV6_REBOOT_PKG_NAME" "$pkgs_file"; then
        printf '%s\n' "$BSSS_IPV6_REBOOT_PKG_NAME" >> "$pkgs_file"
        log_info "$(_ "ipv6.info.reboot_pkg_added" "$BSSS_IPV6_REBOOT_PKG_NAME" "$pkgs_file")"
    fi
}
