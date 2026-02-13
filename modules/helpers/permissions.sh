# @type:        Source
# @description: Находит последний префикс файла конфигурации permissions
#               Не учитывает bsss файлы по маске BSSS_PERMISSIONS_CONFIG_FILE_MASK
# @stdin:       нет
# @stdout:      prefix (число) или пустая строка если файлов нет
# @exit_code:   0
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


# @type:        Source
# @description: Генерирует пункты меню в зависимости от текущего состояния
# @params:      нет
# @stdin:       нет
# @stdout:      id|text\0 (NUL-separated)
# @exit_code:   0
permissions::menu::get_items() {
    if permissions::rules::is_configured; then
        printf '%s|%s\0' "1" "Удалить правила ${UTIL_NAME^^} (откат)"
    else
        printf '%s|%s\0' "1" "Создать правила"
    fi
    printf '%s|%s\0' "0" "Выход"
}

# === FILTER ===

# @type:        Filter
# @description: Подсчитывает количество пунктов меню
# @params:      нет
# @stdin:       нет
# @stdout:      count (число)
# @exit_code:   0
permissions::menu::count_items() {
    permissions::menu::get_items | grep -cz '^'
}

# @type:        Filter
# @description: Получает выбор пользователя из меню
# @params:      нет
# @stdin:       нет
# @stdout:      menu_id
# @exit_code:   0 - выбран пункт
#               2 - отмена пользователем (выбран 0 или отказ)
permissions::menu::get_user_choice() {
    local qty_items=$(($(permissions::menu::count_items) - 1))
    local pattern="^[0-$qty_items]$"
    local hint="0-$qty_items"

    io::ask_value "Выберите пункт" "" "$pattern" "$hint" "0"
}

# === VALIDATOR ===

# @type:        Validator
# @description: Проверяет наличие BSSS конфигурации permissions
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - конфигурация существует
#               1 - конфигурация отсутствует
permissions::rules::is_configured() {
    compgen -G "${SSH_CONFIGD_DIR}/*${BSSS_PERMISSIONS_CONFIG_FILE_MASK}" >/dev/null
}

# === SINK ===

# @type:        Sink
# @description: Логирует все BSSS конфигурации permissions
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
# @description: Логирует все сторонние конфигурации permissions
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

# @type:        Sink
# @description: Отображает инструкции guard для пользователя
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
permissions::log::guard_instructions() {
    log_attention "$(_ "permissions.guard.dont_close")"
    log_attention "$(_ "permissions.guard.test_access")"
}

# @type:        Orchestrator
# @description: Создает файл конфигурации SSH с настройками доступа
#               Отключает логин root и по паролю, включает вход по ключам
# @stdin:       нет
# @stdout:      path к созданному файлу
# @exit_code:   0 - успешно
#               1 - ошибка создания файла
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
        log_info "Файл создан [$path]"
        printf '%s\n' "$path"
    else
        log_error "Ошибка при создании файла с правами доступа [$path])"
        return 1
    fi
}

# @type:        Sink
# @description: Удаляет все BSSS конфигурации permissions
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
permissions::rules::restore() {
    sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_PERMISSIONS_CONFIG_FILE_MASK" | sys::file::delete || true
}

# @type:        Filter
# @description: Определяет действие для правил в зависимости от состояния
# @params:      нет
# @stdin:       нет
# @stdout:      action (restore или install)
# @exit_code:   0
permissions::toggle::rules() {
    if permissions::rules::is_configured; then
        printf 'restore\n'
    else
        printf 'install\n'
    fi
}

# @type:        Sink
# @description: Отображает меню пользователю
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0
permissions::menu::display() {
    local id
    local text

    log_info "$(_ "common.menu_header")"

    while IFS='|' read -r -d '' id text || break; do
        log_info_simple_tab "$(_ "no_translate" "$id. $text")"
    done < <(permissions::menu::get_items)
}

# @type:        Orchestrator
# @description: Отображает статусы permissions: BSSS правила, сторонние правила
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - Всегда успешно
permissions::orchestrator::log_statuses() {
    permissions::log::bsss_configs
    permissions::log::other_configs
}

# @type:        Orchestrator
# @description: Выполняет откат правил permissions и рестарт сервиса
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
permissions::orchestrator::restore::rules() {
    permissions::rules::restore
    sys::service::restart
    log_actual_info
    permissions::orchestrator::log_statuses
}

# @type:        Orchestrator
# @description: Создает правила permissions с механизмом rollback
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
permissions::orchestrator::install::rules() {

    make_fifo_and_start_reader
    WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "permissions")

    permissions::log::guard_instructions

    permissions::rules::make_bsss_rules
    sys::service::restart
    log_actual_info
    permissions::orchestrator::log_statuses

    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "$(_ "common.exit" "0")"

    if io::ask_value "$(_ "permissions.install.confirm_connection")" "" "^connected$" "connected" "0" >/dev/null; then
        rollback::orchestrator::watchdog_stop
        log_info "$(_ "permissions.success_changes_committed")"
    else
        permissions::orchestrator::trigger_immediate_rollback
    fi
}

# @type:        Orchestrator
# @description: Инициирует немедленный откат через SIGUSR2 и ожидает завершения watchdog
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - откат выполнен, процесс заблокирован
permissions::orchestrator::trigger_immediate_rollback() {
    kill -USR2 "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
    while true; do sleep 1; done
}
