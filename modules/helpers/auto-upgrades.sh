# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Проверяет установлен ли unattended-upgrades
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 установлен
#               1 не установлен
auto::upgrades::is_installed() {
    dpkg -s unattended-upgrades >/dev/null 2>&1
}

# @type:        Validator
# @description: Проверяет, настроены ли автообновления по наличию бэкапов
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 бэкапы существуют (настроено)
#               1 бэкапы отсутствуют (не настроено)
auto::upgrades::is_configured() {
    [[ -f "$APT_AUTO_UPGRADES_BACKUP" && -f "$APT_UNATTENDED_UPGRADES_BACKUP" ]]
}

# @type:        Orchestrator
# @description: Устанавливает пакет unattended-upgrades
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка установки
#               4 требуется предварительная настройка
auto::upgrades::ensure_package() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "$(_ "system.update.apt_not_found")"
        return 1
    fi

    if auto::upgrades::is_installed; then
        log_info "$(_ "common.install.success" "unattended-upgrades")"
        return 0
    fi

    log_warn "$(_ "common.install.not_installed" "unattended-upgrades")"
    if ! io::confirm_action "$(_ "common.install.confirm" "unattended-upgrades")"; then
        return 4
    fi

    log_info "$(_ "common.log_command" "DEBIAN_FRONTEND=noninteractive apt-get update")"
    if ! DEBIAN_FRONTEND=noninteractive apt-get update 1>&3; then
        log_error "$(_ "common.install.error" "unattended-upgrades")"
        return 1
    fi

    log_info "$(_ "common.log_command" "DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades")"
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades 1>&3; then
        log_error "$(_ "common.install.error" "unattended-upgrades")"
        return 1
    fi

    log_info "$(_ "common.install.success" "unattended-upgrades")"
}

# @type:        Orchestrator
# @description: Создает бэкап файла настроек, если бэкап отсутствует
# @params:      source_path Путь к исходному файлу (path\n)
#               backup_path Путь к бэкапу (path\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка создания бэкапа
auto::upgrades::backup_file() {
    local source_path="$1"
    local backup_path="$2"

    if [[ -f "$backup_path" ]]; then
        log_info "$(_ "auto.upgrades.backup.exists" "$backup_path")"
        return 0
    fi

    if [[ ! -f "$source_path" ]]; then
        log_warn "$(_ "auto.upgrades.backup.missing_source" "$source_path")"
        return 0
    fi

    local res
    if res=$(cp -pv "$source_path" "$backup_path" 2>&1); then
        log_info "$(_ "auto.upgrades.backup.created" "$res")"
    else
        log_error "$(_ "auto.upgrades.backup.failed" "$backup_path" "$res")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Создает бэкапы конфигураций автообновлений
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка создания бэкапа
auto::upgrades::backup_files() {
    auto::upgrades::backup_file "$APT_AUTO_UPGRADES_FILE" "$APT_AUTO_UPGRADES_BACKUP" || return 1
    auto::upgrades::backup_file "$APT_UNATTENDED_UPGRADES_FILE" "$APT_UNATTENDED_UPGRADES_BACKUP" || return 1
}

# @type:        Orchestrator
# @description: Восстанавливает файл настроек из бэкапа и удаляет бэкап
# @params:      backup_path Путь к бэкапу (path\n)
#               target_path Путь к целевому файлу (path\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка восстановления
auto::upgrades::restore_file() {
    local backup_path="$1"
    local target_path="$2"

    if [[ ! -f "$backup_path" ]]; then
        log_warn "$(_ "auto.upgrades.restore.missing_backup" "$backup_path")"
        return 0
    fi

    local res
    if res=$(cp -pv "$backup_path" "$target_path" 2>&1); then
        log_info "$(_ "auto.upgrades.restore.success" "$res")"
    else
        local rc=$?
        log_error "$(_ "auto.upgrades.restore.failed" "$target_path" "$res")"
        return "$rc"
    fi

    printf '%s\0' "$backup_path" | sys::file::delete || return 1
}

# @type:        Orchestrator
# @description: Восстанавливает конфигурации автообновлений из бэкапов
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка восстановления
auto::upgrades::restore_files() {
    auto::upgrades::restore_file "$APT_AUTO_UPGRADES_BACKUP" "$APT_AUTO_UPGRADES_FILE" || return 1
    auto::upgrades::restore_file "$APT_UNATTENDED_UPGRADES_BACKUP" "$APT_UNATTENDED_UPGRADES_FILE" || return 1
}

# @type:        Orchestrator
# @description: Записывает минимальные конфигурации автообновлений
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка записи
auto::upgrades::write_configs() {
    if [[ ! -f "$APT_AUTO_UPGRADES_FILE" ]]; then
        if ! touch "$APT_AUTO_UPGRADES_FILE"; then
            log_error "$(_ "common.error.create_file" "$APT_AUTO_UPGRADES_FILE")"
            return 1
        fi
    fi

    if cat >> "$APT_AUTO_UPGRADES_FILE" << EOF

// $BSSS_MARKER_COMMENT
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
    then
        log_info "$(_ "auto.upgrades.config.appended" "$APT_AUTO_UPGRADES_FILE")"
    else
        log_error "$(_ "common.error.create_file" "$APT_AUTO_UPGRADES_FILE")"
        return 1
    fi

    if [[ ! -f "$APT_UNATTENDED_UPGRADES_FILE" ]]; then
        if ! touch "$APT_UNATTENDED_UPGRADES_FILE"; then
            log_error "$(_ "common.error.create_file" "$APT_UNATTENDED_UPGRADES_FILE")"
            return 1
        fi
    fi

    if cat >> "$APT_UNATTENDED_UPGRADES_FILE" << EOF

// $BSSS_MARKER_COMMENT
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
    then
        log_info "$(_ "auto.upgrades.config.appended" "$APT_UNATTENDED_UPGRADES_FILE")"
    else
        log_error "$(_ "common.error.create_file" "$APT_UNATTENDED_UPGRADES_FILE")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Включает автообновления и автоперезагрузку
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка настройки
#               4 требуется предварительная настройка
auto::upgrades::orchestrator::enable() {
    auto::upgrades::ensure_package || return $?

    auto::upgrades::backup_files || return 1
    auto::upgrades::write_configs || return 1

    log_info "$(_ "common.log_command" "DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades")"
    if ! DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades 1>&3; then
        log_error "$(_ "auto.upgrades.reconfigure.failed")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Отключает автообновления и автоперезагрузку
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               1 ошибка восстановления
auto::upgrades::orchestrator::disable() {
    auto::upgrades::restore_files
}
