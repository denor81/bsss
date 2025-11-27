#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Глобальная переменная для хранения SSH порта между шагами
declare -g SSH_PORT=""

# Флаги командной строки
declare -g CHECK_MODE=false
declare -g DEFAULT_MODE=false
declare -g VERBOSE_MODE=false

# Подключение модулей
source "${CACHE_BASE}/system-check.sh"
source "${CACHE_BASE}/system-update.sh"
source "${CACHE_BASE}/ssh-port.sh"
source "${CACHE_BASE}/ipv6-disable.sh"
source "${CACHE_BASE}/ssh-auth.sh"
source "${CACHE_BASE}/ufw-setup.sh"

# Функция парсинга аргументов
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                CHECK_MODE=true
                shift
                ;;
            --default)
                DEFAULT_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            *)
                echo "Неизвестный параметр: $1" >&2
                exit 1
                ;;
        esac
    done
}

# Универсальная функция выполнения шага
execute_step() {
    local step_function="$1"
    local step_description="$2"
    
    log_step "$step_description"
    
    if [[ "$CHECK_MODE" == true ]]; then
        "${step_function}" --check
    elif [[ "$DEFAULT_MODE" == true ]]; then
        if [[ "$step_function" =~ ^(ssh_port|ipv6_disable|ssh_auth|ufw_setup)$ ]]; then
            "${step_function}" --default
        fi
    else
        "${step_function}"
    fi
}

# Основная функция выполнения
main() {
    parse_arguments "$@"
    
    # Проверка прав
    check_root_permissions
    
    # Последовательное выполнение шагов
    execute_step "system_check" "Проверка необходимости перезагрузки"
    execute_step "system_update" "Обновление системы"
    execute_step "ssh_port" "Настройка SSH порта"
    execute_step "ipv6_disable" "Отключение IPv6"
    execute_step "ssh_auth" "Настройка авторизации SSH"
    execute_step "ufw_setup" "Настройка брандмауэра"
}

main "$@"