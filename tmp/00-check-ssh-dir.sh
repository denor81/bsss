#!/usr/bin/env bash
# 00-check-ssh-dir.sh
# Нулевой модуль системы
# Проверяет наличие директории /etc/ssh/sshd_config.d/
# MODULE_TYPE: check-only

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}/../lib/logging.sh"

# TESTED: tests/test_check_ssh_dir.sh
check() {
    local ssh_config_dir=${1:-$SSH_CONFIG_DIR}
    local status
    local message
    local symbol

    if [[ -d "$ssh_config_dir" ]]; then
        status=0
        message="Директория $ssh_config_dir существует"
        symbol="$SYMBOL_INFO"
    else
        status=1
        message="Директория $ssh_config_dir не найдена. Система слишком старая для этого скрипта."
        symbol="$SYMBOL_ERROR"
    fi
    
    # Вывод в Key-Value формате для парсинга через eval
    echo "message=\"$(printf '%s' "$message" | base64)\""
    echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
    echo "status=$status"
}

main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi