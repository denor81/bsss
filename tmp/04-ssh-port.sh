#!/usr/bin/env bash
# module-04.sh
# Четвертый модуль системы
# Проверяет SSH порт
# Usage: ./04-ssh-port.sh [-c]
#   -c  Экспресс-анализ с выводом в Key-Value формате

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
# shellcheck disable=SC2155
readonly SCRIPT_NAME=$(basename "$0")
# shellcheck disable=SC2034
readonly CURRENT_MODULE_NAME="$SCRIPT_NAME"
readonly ALLOWED_PARAMS="c"

# Флаги режимов работы
CHECK_FLAG=0  # Режим экспресс-анализа


# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}"/../lib/logging.sh

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========

# Парсер параметров командной строки
_parse_params() {
    local allowed_params="${1:-$ALLOWED_PARAMS}"
    shift

    # Сбрасываем OPTIND
    OPTIND=1
    
    while getopts ":$allowed_params" opt "$@"; do
        case "${opt}" in
            c)  CHECK_FLAG=1 ;;
            \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params" >&2 ;;
            :)  log_error "Параметр -$OPTARG требует значение" >&2 ;;
        esac
    done
}

# check() {
#     log_info "ЗАПУСК МОДУЛЯ $SCRIPT_NAME В РЕЖИМЕ ПРОВЕРКИ"
    
#     # Проверяем текущий активный порт SSH
#     if [[ -n "${SSH_CLIENT:-}" ]]; then
#         local ssh_port="${SSH_CLIENT##* }"
#         log_info "Текущий активный порт SSH: $ssh_port"
#     else
#         log_error "Не возможно определлить порт через SSH_CLIENT (Возможно виртуальная машина)"
#         # Fallback
#     fi
    
#     return "$SUCCESS"
# }

# Временная функция для отладки
# check() {
#     echo "=== ДИАГНОСТИКА SSH ПОРТА ==="
    
#     # 1. Проверяем процессы sshd
#     echo "1. Процессы sshd:"
#     ps aux | grep -E '[s]shd' || echo "Не найдены"
    
#     # 2. Проверяем ss с разными флагами
#     echo -e "\n2. Вывод ss -tlnp:"
#     sudo ss -tlnp 2>&1 | head -20
    
#     echo -e "\n3. Вывод ss -tlnp | grep ssh:"
#     sudo ss -tlnp 2>&1 | grep -i ssh || echo "Не найдено"
    
#     # 3. Проверяем netstat
#     echo -e "\n4. Вывод netstat -tlnp:"
#     sudo netstat -tlnp 2>&1 | head -20 || echo "Netstat недоступен"
    
#     # 4. Проверяем порт 22
#     echo -e "\n5. Проверка порта 22:"
#     sudo ss -tln 2>&1 | grep ":22" || echo "Порт 22 не слушается"
    
#     echo "=== КОНЕЦ ДИАГНОСТИКИ ==="
# }

check() {
    local status=0
    local message="SSH порт: 22"
    local details="Служба SSH работает на стандартном порту"
    local ssh_port="22"
    
    # Основная логика определения порта
    local listener_pid
    listener_pid=$(ps aux | awk '/[s]shd.*\[listener\]/ {print $2; exit}')
    
    if [[ -n "$listener_pid" ]] && [[ -f "/proc/$listener_pid/net/tcp" ]]; then
        # Самый надежный метод для Linux
        ssh_port=$(awk '$4 ~ /:0016$/ {split($4, a, ":"); print strtonum("0x" a[2]); exit}' \
                   "/proc/$listener_pid/net/tcp" 2>/dev/null)
    fi
    
    if [[ -z "$ssh_port" ]] && command -v ss >/dev/null 2>&1; then
        ssh_port=$(sudo ss -tln 2>/dev/null | \
                   awk '/:22[[:space:]]/ && /LISTEN/ {print "22"; exit}')
    fi
    
    ssh_port="${ssh_port:-22}"
    
    # Определяем статус
    if [[ -z "$listener_pid" ]]; then
        status=1
        message="SSH сервис не найден"
        details="Процесс sshd не обнаружен в системе"
    elif [[ "$ssh_port" != "22" ]]; then
        status=0
        message="SSH порт: $ssh_port (не стандартный)"
        details="SSH работает на нестандартном порту"
    else
        message="SSH порт: $ssh_port"
        details="Служба SSH работает на стандартном порту"
    fi
    
    # Вывод в Key-Value формате
    echo "module=$SCRIPT_NAME"
    echo "status=$status"
    echo "message=$message"
    echo "details=$details"
    
    # Возвращаем код в зависимости от статуса
    if [[ "$status" -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Вызовите debug_ssh_port в вашем скрипте для диагностики


# Альтернативный вариант - более компактный и надежный
# check() {
#     local port
    
#     # 1. Через ss с поиском процесса sshd
#     if command -v ss >/dev/null 2>&1; then
#         port=$(sudo ss -tlnp 2>/dev/null | \
#                awk 'BEGIN {IGNORECASE=1} /sshd/ && /LISTEN/ {
#                    split($4, a, ":");
#                    port = a[length(a)];
#                    if (port ~ /^[0-9]+$/) {
#                        print port;
#                        exit 0
#                    }
#                }')
#     fi
    
#     # 2. Если не сработало, проверяем все открытые порты SSH
#     if [[ -z "$port" ]]; then
#         for test_port in 22 2222 22222 2200 2022; do
#             if sudo ss -tln 2>/dev/null | grep -q ":${test_port}[[:space:]]"; then
#                 port="$test_port"
#                 break
#             fi
#         done
#     fi
    
#     # 3. Проверка через lsof (если есть)
#     if [[ -z "$port" ]] && command -v lsof >/dev/null 2>&1; then
#         port=$(sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | \
#                awk '/sshd/ {split($9, a, ":"); print a[2]; exit}')
#     fi
    
#     log_info "${port:-22}"
# }


run() {
    log_info "ЗАПУСК МОДУЛЯ $SCRIPT_NAME В СТАНДАРТНОМ РЕЖИМЕ"
    return 0
}

# ========== ОСНОВНАЯ ФУНКЦИЯ ==========

main() {
    # Если нет параметров, используем режим check по умолчанию
    if [[ "$#" -eq 0 ]]; then
        CHECK_FLAG=1
    fi
    
    # Парсим параметры
    _parse_params "$ALLOWED_PARAMS" "$@"
    
    # Выполняем в зависимости от режима
    if [[ "$CHECK_FLAG" -eq 1 ]]; then
        check
    else
        log_error "Не определен режим запуска. Используйте -c для проверки"
        return 1
    fi
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
