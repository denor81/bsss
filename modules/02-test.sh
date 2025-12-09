#!/usr/bin/env bash
# module-01.sh
# Тестовый
# Возвращает код успеха 0

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
# shellcheck disable=SC2155
readonly SCRIPT_NAME=$(basename "$0")
# shellcheck disable=SC2034
readonly CURRENT_MODULE_NAME="$SCRIPT_NAME"

CHECK_FLAG=1


# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}"/../lib/logging.sh

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
    log_info "ЗАПУСК МОДУЛЯ $SCRIPT_NAME В РЕЖИМЕ ПРОВЕРКИ"
    
    echo "=== ДИАГНОСТИКА ==="
    
    # 1. Проверяем процессы
    echo "1. Поиск процессов sshd:"
    ps aux | grep -E '[s]shd' | head -5
    
    # 2. Ищем [listener]
    local listener_pid
    listener_pid=$(ps aux | awk '/[s]shd.*\[listener\]/ {print $2; exit}')
    echo "2. PID процесса с [listener]: $listener_pid"
    
    # 3. Проверяем /proc
    if [[ -n "$listener_pid" ]] && [[ -d "/proc/$listener_pid" ]]; then
        echo "3. Проверка /proc/$listener_pid/net/tcp:"
        if [[ -f "/proc/$listener_pid/net/tcp" ]]; then
            grep -E ":0016[[:space:]]" "/proc/$listener_pid/net/tcp" || echo "Не найден порт 22 в /proc"
        else
            echo "Файл /proc/$listener_pid/net/tcp не существует"
        fi
    fi
    
    # 4. Проверяем ss
    echo "4. Вывод ss -tlnp для ssh:"
    sudo ss -tlnp 2>&1 | grep -i ssh || echo "Не найдено"
    
    # 5. Основная логика
    local ssh_port
    listener_pid=$(ps aux | awk '/[s]shd.*\[listener\]/ {print $2; exit}')
    
    if [[ -n "$listener_pid" ]] && [[ -f "/proc/$listener_pid/net/tcp" ]]; then
        # Самый надежный метод для Linux
        ssh_port=$(awk '$4 ~ /:0016$/ {split($4, a, ":"); print strtonum("0x" a[2]); exit}' \
                   "/proc/$listener_pid/net/tcp" 2>/dev/null)
        echo "5. Порт из /proc: $ssh_port"
    fi
    
    if [[ -z "$ssh_port" ]] && command -v ss >/dev/null 2>&1; then
        ssh_port=$(sudo ss -tln 2>/dev/null | \
                   awk '/:22[[:space:]]/ && /LISTEN/ {print "22"; exit}')
        echo "6. Порт из ss: $ssh_port"
    fi
    
    ssh_port="${ssh_port:-22}"
    echo "7. Итоговый порт: $ssh_port"
    
    echo "=== КОНЕЦ ДИАГНОСТИКИ ==="
    
    log_info "Текущий активный порт SSH: $ssh_port"
    echo "$ssh_port"
    return 0
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

main() {
    if [[ "$CHECK_FLAG" -eq 1 ]]; then
        check
    elif [[ "$CHECK_FLAG" -eq 0 ]]; then
        run
    fi
    log_error "Не определен флаг запуска"
    return 1
}

main 
