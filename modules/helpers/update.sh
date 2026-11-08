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
