#!/usr/bin/env bash
# Установлен ufw или нет
# MODULE_TYPE: check

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"
source "${MODULES_DIR_PATH}/../lib/user_confirmation.sh"

check() {
    if command -v ufw > /dev/null 2>&1; then
        log_info "UFW установлен"
    else
        log_error "UFW не установлен"
        if confirm_action "Установить UFW сейчас? [apt update && apt install ufw -y]" || return; then
            if ! (apt update && apt install ufw -y); then
                log_error "Ошибка при установке UFW"
                return 1
            else
                if command -v ufw > /dev/null 2>&1; then
                    log_info "UFW успешно установлен"
                else
                    log_info "UFW установлен - перезапустите скрипт"
                    return 1
                fi
            fi
        fi
    fi


}


main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi