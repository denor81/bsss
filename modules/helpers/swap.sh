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

# @type:        Filter
# @description: Нормализует размер swap файла (uppercase, без суффикса B)
# @params:      size Размер swap файла (string\n)
# @stdin:       нет
# @stdout:      size_normalized\n
# @exit_code:   0 успешно
#               1 ошибка
swap::size::normalize() {
    local size="$1"
    size="${size^^}"
    size="${size%B}"

    if [[ -z "$size" ]]; then
        log_error "$(_ "swap.error.size_invalid" "$1")"
        return 1
    fi

    printf '%s' "$size"
}

# @type:        Filter
# @description: Переводит размер swap в байты
# @params:      size_normalized Нормализованный размер (string\n)
#               size_raw Исходный размер для сообщения об ошибке (string\n)
# @stdin:       нет
# @stdout:      bytes\n
# @exit_code:   0 успешно
#               1 ошибка
swap::size::to_bytes() {
    local size_normalized="$1"
    local size_raw="$2"
    local bytes

    if ! bytes=$(numfmt --from=iec "$size_normalized" 2>/dev/null); then
        log_error "$(_ "swap.error.size_invalid" "$size_raw")"
        return 1
    fi

    printf '%s' "$bytes"
}

# @type:        Filter
# @description: Переводит байты в человекочитаемый формат
# @params:      bytes Количество байт (num\n)
# @stdin:       нет
# @stdout:      human\n
# @exit_code:   0 успешно
#               1 ошибка
swap::size::to_human() {
    local bytes="$1"
    local human

    if ! human=$(numfmt --to=iec --suffix=B "$bytes" 2>/dev/null); then
        printf '%s' "$bytes"
        return 1
    fi

    printf '%s' "$human"
}

# @type:        Filter
# @description: Возвращает доступные байты для раздела swap файла
# @stdin:       нет
# @stdout:      bytes\n
# @exit_code:   0 успешно
#               1 ошибка
swap::disk::get_avail_bytes() {
    local mount_path
    local avail_bytes

    mount_path=$(dirname "$SWAPFILE_PATH")
    if ! avail_bytes=$(df -B1 --output=avail "$mount_path" 2>/dev/null | gawk 'NR==2 {print $1}'); then
        log_warn "$(_ "swap.error.disk_stats_failed" "$mount_path")"
        return 1
    fi

    if [[ -z "$avail_bytes" ]]; then
        log_warn "$(_ "swap.error.disk_stats_failed" "$mount_path")"
        return 1
    fi

    printf '%s' "$avail_bytes"
}

# @type:        Validator
# @description: Проверяет достаточность свободного места для swap
# @params:      required_bytes Требуемый размер (num\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 достаточно
#               1 недостаточно или ошибка
swap::disk::check_space() {
    local required_bytes="$1"
    local avail_bytes
    local required_h
    local avail_h

    avail_bytes=$(swap::disk::get_avail_bytes) || return 1

    if (( avail_bytes < required_bytes )); then
        required_h=$(swap::size::to_human "$required_bytes" 2>/dev/null || printf '%s' "$required_bytes")
        avail_h=$(swap::size::to_human "$avail_bytes" 2>/dev/null || printf '%s' "$avail_bytes")
        log_error "$(_ "swap.error.insufficient_space" "$required_h" "$avail_h")"
        return 1
    fi
}

# @type:        Filter
# @description: Возвращает размер swap файла в байтах
# @stdin:       нет
# @stdout:      bytes\n
# @exit_code:   0 успешно
#               1 ошибка
swap::size::current_bytes() {
    if ! swap::file::exists; then
        return 1
    fi

    stat -c "%s" "$SWAPFILE_PATH" 2>/dev/null
}

# @type:        Filter
# @description: Возвращает размер swap файла в человекочитаемом формате
# @stdin:       нет
# @stdout:      human\n
# @exit_code:   0 успешно
#               1 ошибка
swap::size::current_human() {
    local bytes
    bytes=$(swap::size::current_bytes) || return 1
    swap::size::to_human "$bytes"
}

# @type:        Orchestrator
# @description: Создает swap файл при отсутствии
# @params:      size Размер swap файла (string\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка создания
swap::file::create() {
    local size="$1"

    if command -v fallocate >/dev/null 2>&1; then
        log_info "$(_ "common.log_command" "fallocate -l $size $SWAPFILE_PATH")"
        local res
        if ! res=$(fallocate -l "$size" "$SWAPFILE_PATH" 2>&1); then
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
# @params:      size Размер swap файла (string\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка
swap::orchestrator::enable() {
    local size_input="${1:-$SWAPFILE_SIZE}"
    local size_normalized
    local required_bytes

    if swap::state::is_configured; then
        log_info "$(_ "swap.info.already_configured")"
        return 0
    fi

    size_normalized=$(swap::size::normalize "$size_input") || return 1
    required_bytes=$(swap::size::to_bytes "$size_normalized" "$size_input") || return 1
    swap::disk::check_space "$required_bytes" || return 1

    if swap::state::is_active; then
        log_info "$(_ "common.log_command" "swapoff $SWAPFILE_PATH")"
        local res
        if ! res=$(swapoff "$SWAPFILE_PATH" 2>&1); then
            log_error "$(_ "swap.error.swapoff_failed" "${res:-$SWAPFILE_PATH}")"
            return 1
        fi
    fi

    if swap::file::exists; then
        log_info "$(_ "swap.info.file_recreate" "$SWAPFILE_PATH")"
        printf '%s\0' "$SWAPFILE_PATH" | sys::file::delete || return 1
    fi

    swap::file::create "$size_normalized" || return 1
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
