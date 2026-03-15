# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Проверяет наличие swap файла
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 файл существует
#               1 файл отсутствует
swap::file::exists() {
    [[ -f "$SWAPFILE_PATH" ]]
}

# @type:        Validator
# @description: Проверяет активен ли swap файл
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 активен
#               1 не активен
swap::state::is_active() {
    swapon --show=NAME --noheadings 2>/dev/null \
        | gawk -v target="$SWAPFILE_PATH" '$1 == target { found=1 } END { exit found ? 0 : 1 }'
}

# @type:        Validator
# @description: Проверяет наличие записи swap в fstab
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 запись найдена
#               1 запись отсутствует
swap::fstab::has_entry() {
    [[ -f "$SWAPFILE_FSTAB_PATH" ]] || return 1
    gawk -v entry="$SWAPFILE_FSTAB_ENTRY" '$0 == entry { found=1 } END { exit found ? 0 : 1 }' "$SWAPFILE_FSTAB_PATH"
}

# @type:        Validator
# @description: Проверяет, настроен ли swap файл
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 настроен
#               1 не настроен
swap::state::is_configured() {
    swap::file::exists && swap::fstab::has_entry && swap::state::is_active
}

# @type:        Sink
# @description: Логирует показатели свободного места на диске
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка получения данных
swap::log::disk_stats() {
    local mount_path
    local res
    local total_bytes
    local avail_bytes
    local total_h
    local avail_h
    local swap_bytes
    local swap_h

    mount_path=$(dirname "$SWAPFILE_PATH")
    if ! res=$(df -B1 --output=size,avail "$mount_path" 2>/dev/null | gawk 'NR==2 {print $1 " " $2}'); then
        log_warn "$(_ "swap.error.disk_stats_failed" "$mount_path")"
        return 1
    fi

    read -r total_bytes avail_bytes <<< "$res"
    if [[ -z "$total_bytes" || -z "$avail_bytes" ]]; then
        log_warn "$(_ "swap.error.disk_stats_failed" "$mount_path")"
        return 1
    fi

    if ! total_h=$(numfmt --to=iec --suffix=B "$total_bytes" 2>/dev/null); then
        total_h="$total_bytes"
    fi
    if ! avail_h=$(numfmt --to=iec --suffix=B "$avail_bytes" 2>/dev/null); then
        avail_h="$avail_bytes"
    fi

    log_info "$(_ "swap.info.disk_header")"

    if swap::state::is_active; then
        swap_bytes=$(swapon --show=NAME,SIZE --bytes --noheadings 2>/dev/null \
            | gawk -v target="$SWAPFILE_PATH" '$1 == target { print $2; exit }')
        if [[ -n "$swap_bytes" ]]; then
            if ! swap_h=$(numfmt --to=iec --suffix=B "$swap_bytes" 2>/dev/null); then
                swap_h="$swap_bytes"
            fi
            log_info_simple_tab "$(_ "swap.info.disk_total_free_swap" "$total_h" "$avail_h" "$swap_h")"
            return 0
        fi
    fi

    log_info_simple_tab "$(_ "swap.info.disk_total_free" "$total_h" "$avail_h")"
}

# @type:        Orchestrator
# @description: Создает swap файл при отсутствии
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка создания
swap::file::create() {
    if swap::file::exists; then
        log_info "$(_ "swap.info.file_exists" "$SWAPFILE_PATH")"
        return 0
    fi

    if command -v fallocate >/dev/null 2>&1; then
        log_info "$(_ "common.log_command" "fallocate -l $SWAPFILE_SIZE $SWAPFILE_PATH")"
        local res
        if ! res=$(fallocate -l "$SWAPFILE_SIZE" "$SWAPFILE_PATH" 2>&1); then
            log_error "$(_ "swap.error.file_create" "${res:-$SWAPFILE_PATH}")"
            return 1
        fi
    else
        log_error "$(_ "swap.error.fallocate_missing")"
        return 1
    fi

    log_info "$(_ "swap.info.file_created" "$SWAPFILE_PATH")"
}

# @type:        Orchestrator
# @description: Устанавливает права 600 на swap файл
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
swap::file::ensure_permissions() {
    if ! swap::file::exists; then
        log_error "$(_ "swap.error.file_missing" "$SWAPFILE_PATH")"
        return 1
    fi

    log_info "$(_ "common.log_command" "chmod 600 $SWAPFILE_PATH")"
    local res
    if ! res=$(chmod 600 "$SWAPFILE_PATH" 2>&1); then
        log_error "$(_ "swap.error.chmod_failed" "${res:-$SWAPFILE_PATH}")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Добавляет запись swap в fstab при отсутствии
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
swap::fstab::append_entry() {
    if [[ ! -f "$SWAPFILE_FSTAB_PATH" ]]; then
        log_error "$(_ "swap.error.fstab_missing" "$SWAPFILE_FSTAB_PATH")"
        return 1
    fi

    if swap::fstab::has_entry; then
        log_info "$(_ "swap.info.fstab_exists" "$SWAPFILE_FSTAB_PATH")"
        return 0
    fi

    log_info "$(_ "common.log_command" "printf '%s' '$SWAPFILE_FSTAB_ENTRY' >> $SWAPFILE_FSTAB_PATH")"
    if printf '%s\n' "$SWAPFILE_FSTAB_ENTRY" >> "$SWAPFILE_FSTAB_PATH"; then
        log_info "$(_ "swap.info.fstab_added" "$SWAPFILE_FSTAB_PATH")"
    else
        log_error "$(_ "swap.error.fstab_add_failed" "$SWAPFILE_FSTAB_PATH")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Удаляет запись swap из fstab при наличии
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
swap::fstab::remove_entry() {
    if [[ ! -f "$SWAPFILE_FSTAB_PATH" ]]; then
        log_error "$(_ "swap.error.fstab_missing" "$SWAPFILE_FSTAB_PATH")"
        return 1
    fi

    if ! swap::fstab::has_entry; then
        log_info "$(_ "swap.info.fstab_missing" "$SWAPFILE_FSTAB_PATH")"
        return 0
    fi

    local tmp
    tmp=$(mktemp)
    if gawk -v entry="$SWAPFILE_FSTAB_ENTRY" '$0 != entry' "$SWAPFILE_FSTAB_PATH" > "$tmp"; then
        mv "$tmp" "$SWAPFILE_FSTAB_PATH"
        log_info "$(_ "swap.info.fstab_removed" "$SWAPFILE_FSTAB_PATH")"
    else
        log_error "$(_ "swap.error.fstab_remove_failed" "$SWAPFILE_FSTAB_PATH")"
        [[ -n "$tmp" ]] && printf '%s\0' "$tmp" | sys::file::delete
        return 1
    fi
}

# @type:        Orchestrator
# @description: Включает swap файл
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
swap::orchestrator::enable() {
    if swap::state::is_configured; then
        log_info "$(_ "swap.info.already_configured")"
        return 0
    fi

    swap::file::create || return 1
    swap::file::ensure_permissions || return 1

    if ! swap::state::is_active; then
        log_info "$(_ "common.log_command" "mkswap $SWAPFILE_PATH")"
        local res
        if ! res=$(mkswap "$SWAPFILE_PATH" 2>&1); then
            log_error "$(_ "swap.error.mkswap_failed" "${res:-$SWAPFILE_PATH}")"
            return 1
        fi
        log_info "$(_ "swap.info.mkswap_done")"

        log_info "$(_ "common.log_command" "swapon $SWAPFILE_PATH")"
        if ! res=$(swapon "$SWAPFILE_PATH" 2>&1); then
            log_error "$(_ "swap.error.swapon_failed" "${res:-$SWAPFILE_PATH}")"
            return 1
        fi
    fi

    swap::fstab::append_entry || return 1

    log_info "$(_ "swap.info.enabled")"
}

# @type:        Orchestrator
# @description: Отключает swap файл и очищает конфигурацию
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
swap::orchestrator::disable() {
    if swap::state::is_active; then
        log_info "$(_ "common.log_command" "swapoff $SWAPFILE_PATH")"
        local res
        if ! res=$(swapoff "$SWAPFILE_PATH" 2>&1); then
            log_error "$(_ "swap.error.swapoff_failed" "${res:-$SWAPFILE_PATH}")"
            return 1
        fi
    fi

    swap::fstab::remove_entry || return 1

    if swap::file::exists; then
        printf '%s\0' "$SWAPFILE_PATH" | sys::file::delete || return 1
    fi

    log_info "$(_ "swap.info.disabled")"
}
