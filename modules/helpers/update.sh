# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Source
# @description: Определяет версию последнего опубликованного релиза GitHub
# @stdin:       нет
# @stdout:      version\0
# @exit_code:   0 версия определена
#               1 ошибка запроса или формата версии
update::version::latest() {
    local url version
    log_info "$(_ "update.checking")"
    if ! url=$(curl -fsSL --connect-timeout "$UPDATE_CONNECT_TIMEOUT" --max-time "$UPDATE_REQUEST_TIMEOUT" -o /dev/null -w '%{url_effective}' "$BSSS_LATEST_RELEASE_URL" 2>&3); then
        log_error "$(_ "update.version_failed")"
        return 1
    fi
    version=${url##*/}
    if [[ ! "$url" == "$BSSS_RELEASE_TAG_URL/"* || ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "$(_ "update.version_failed")"
        return 1
    fi
    version=${version#v}
    log_info "$(_ "update.latest" "$version")"
    printf '%s\0' "$version"
}

# @type:        Orchestrator
# @description: Показывает версии и запрашивает согласие на обновление или переустановку
# @stdin:       нет (ввод через TTY)
# @stdout:      нет
# @exit_code:   0 подтверждено
#               1 ошибка определения версии
#               2 отмена пользователем
update::menu::confirm() {
    local version
    version=$(update::version::latest | tr -d '\0') || return
    log_info "$(_ "update.current" "$BSSS_VERSION")"
    if [[ "$version" == "${BSSS_VERSION#v}" ]]; then
        io::confirm_action "$(_ "update.confirm_reinstall")"
    else
        io::confirm_action "$(_ "update.confirm_update")"
    fi
}

# @type:        Sink
# @description: Удаляет временный установщик при завершении процесса обновления
# @params:      rc Код завершения (num) без завершающего символа
#               installer Путь временного установщика (path) без завершающего символа
# @stdin:       нет
# @stdout:      нет
# @exit_code:   rc исходный код завершения
update::installer::cleanup() {
    local rc="$1" installer="$2"
    rm -f "$installer"
    exit "$rc"
}

# @type:        Orchestrator
# @description: Обновляет установленную копию штатным удалением и онлайн-установщиком
# @stdin:       нет (ввод через TTY)
# @stdout:      вывод дочерних процессов
# @exit_code:   0 установка завершена, процесс завершен
#               1 ошибка подготовки, возврат в меню
#               2 отмена до удаления, возврат в меню
#               $? ошибка удаления или установки, процесс завершен
update::orchestrator::run() {
    if [[ ! -f "$UNINSTALL_FILE_PATH" ]] || ! command -v "$UTIL_NAME" >/dev/null 2>&1; then
        log_error "$(_ "update.not_installed")"
        return 1
    fi
    update::menu::confirm || return

    local installer rc=0
    installer=$(mktemp --tmpdir="$UPDATE_TEMP_DIR" "${UTIL_NAME}-update-XXXXXX.sh") || return
    trap 'update::installer::cleanup "$?" "$installer"' EXIT
    log_info "$(_ "update.downloading")"
    if ! curl -fsSL --connect-timeout "$UPDATE_CONNECT_TIMEOUT" --max-time "$UPDATE_DOWNLOAD_TIMEOUT" "$BSSS_INSTALLER_URL" -o "$installer" 2>&3; then
        log_error "$(_ "update.download_failed")"
        rm -f "$installer"
        trap common::exit::actions EXIT
        return 1
    fi
    if [[ ! -s "$installer" ]] || ! bash -n "$installer" 2>&3; then
        log_error "$(_ "update.download_failed")"
        rm -f "$installer"
        trap common::exit::actions EXIT
        return 1
    fi

    log_info "$(_ "update.install_instruction")"
    "$UTIL_NAME" -u 2>&3 || rc=$?
    if (( rc == 2 )); then
        rm -f "$installer"
        trap common::exit::actions EXIT
        return 2
    fi
    if (( rc != 0 )); then
        log_error "$(_ "update.uninstall_failed")"
        exit "$rc"
    fi

    bash "$installer" 2>&3 || rc=$?
    if (( rc != 0 )); then
        log_error "$(_ "update.install_failed" "$BSSS_INSTALLER_URL")"
    fi
    exit "$rc"
}
