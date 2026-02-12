# @type:        Source
# @description: Находит последний префикс файла, содержащего настройки SSH доступа
#               Не учитыввет bsss файлы по маске BSSS_PERMISSIONS_CONFIG_FILE_MASK
# @stdin:       нет
# @stdout:      prefix (число) или пустая строка если файлов нет
# @exit_code:   0
permissions::ssh::find_last_prefix() {
    local file prefix max_prefix=""

    while IFS= read -r -d '' file; do
        [[ ! -f "$file" ]] && continue

        if grep -qE '^\s*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)\b' "$file" 2>/dev/null; then
            basename_file=$(basename "$file")
            prefix="${basename_file%%-*}"
            
            if [[ "$prefix" =~ ^[0-9]+$ ]]; then
                [[ -z "$max_prefix" ]] || (( prefix > max_prefix )) && max_prefix="$prefix"
            fi
        fi
    done < <(find "${SSH_CONFIGD_DIR}" -maxdepth 1 -type f -name "*.conf" ! -name "$BSSS_PERMISSIONS_CONFIG_FILE_MASK" -print0 2>/dev/null)

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

permissions::rules::is_configured() {
    # ls "${SSH_CONFIGD_DIR}"/*"${BSSS_PERMISSIONS_CONFIG_FILE_MASK}" >/dev/null 2>&1
    compgen -G "${SSH_CONFIGD_DIR}/*${BSSS_PERMISSIONS_CONFIG_FILE_MASK}" >/dev/null
}

permissions::rules::restore() {
    sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_PERMISSIONS_CONFIG_FILE_MASK" | sys::file::delete || true
}

permissions::menu::get_items() {
    if permissions::rules::is_configured; then
        printf '%s|%s\0' "1" "Удалить правила (откат)"
    else
        printf '%s|%s\0' "1" "Создать правила"
    fi
    printf '%s|%s\0' "0" "Выход"
}

permissions::menu::display() {
    local id
    local text

    log_info "$(_ "common.menu_header")"

    while IFS='|' read -r -d '' id text || break; do
        log_info_simple_tab "$(_ "no_translate" "$id. $text")"
    done < <(permissions::menu::get_items)
}

permissions::menu::count_items() {
    permissions::menu::get_items | grep -cz '^'
}

permissions::menu::get_user_choice() {
    local qty_items=$(($(permissions::menu::count_items) - 1)) # вычитаем один элемент - 0 пункт меню, что бы корректно отображать маску
    local pattern="^[0-$qty_items]$"
    local hint="0-$qty_items"

    io::ask_value "Выберите пункт" "" "$pattern" "$hint" "0" # Вернет 0 или 2 при отказе (или 130 при ctrl+c)
}

permissions::toggle::rules() {
    if permissions::rules::is_configured; then
        permissions::rules::restore
    else
        permissions::rules::make_bsss_rules
    fi
    sys::service::restart
}
