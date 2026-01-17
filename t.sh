#!/usr/bin/env bash
# Проверяет SSH порт
# MODULE_TYPE: check

set -Eeuo pipefail

# @description Определяет порт SSH через активный TTY (не зависит от окружения)
sys::get_ssh_session_port() {
    local current_tty
    current_tty=$(tty | sed 's|/dev/||')
    
    # Ищем в ss соединение, связанное с нашим TTY
    # Это сработает под sudo, так как ss читает данные напрямую из ядра
    ss -atnp | grep "$current_tty" | awk '{print $4}' | awk -F: '{print $NF}' | head -n1
}



sys::get_ssh_session_port