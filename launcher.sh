#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Конфигурация загрузчика
readonly CACHE_BASE="${HOME}/.cache/bsss"
readonly REMOTE_BASE="https://raw.githubusercontent.com/user/repo/main"
readonly SCRIPT_VERSION="1.0.0"

# Функция загрузки модуля при отсутствии
download_if_missing() {
    local file="$1"
    local remote_path="$2"
    local cache_file="${CACHE_BASE}/${file}"
    
    if [[ ! -f "$cache_file" ]]; then
        mkdir -p "$CACHE_BASE"
        curl -s "${REMOTE_BASE}/${remote_path}" -o "$cache_file"
        chmod +x "$cache_file"
    fi
}

# Проверка и загрузка всех необходимых модулей
load_dependencies() {
    download_if_missing "helpers/common.sh" "modules/helpers/common.sh"
    download_if_missing "helpers/config.sh" "modules/helpers/config.sh"
    download_if_missing "helpers/input.sh" "modules/helpers/input.sh"
    download_if_missing "helpers/logging.sh" "modules/helpers/logging.sh"
    download_if_missing "system-check.sh" "modules/system-check.sh"
    download_if_missing "system-update.sh" "modules/system-update.sh"
    download_if_missing "ssh-port.sh" "modules/ssh-port.sh"
    download_if_missing "ipv6-disable.sh" "modules/ipv6-disable.sh"
    download_if_missing "ssh-auth.sh" "modules/ssh-auth.sh"
    download_if_missing "ufw-setup.sh" "modules/ufw-setup.sh"
    download_if_missing "bsss-main.sh" "bsss-main.sh"
}

# Загрузка модулей и запуск основного скрипта
main() {
    load_dependencies
    
    # Подключение вспомогательных модулей
    source "${CACHE_BASE}/helpers/common.sh"
    source "${CACHE_BASE}/helpers/config.sh"
    source "${CACHE_BASE}/helpers/input.sh"
    source "${CACHE_BASE}/helpers/logging.sh"
    
    # Запуск основного скрипта с передачей аргументов
    source "${CACHE_BASE}/bsss-main.sh" "$@"
}

main "$@"