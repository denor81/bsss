#!/usr/bin/env bash
# 04-ssh-port.sh
# Четвертый модуль системы
# Проверяет и изменяет SSH порт
# Usage: ./04-ssh-port.sh [-r]
#   -r  Режим изменения порта (заглушка)

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
# shellcheck disable=SC2155
readonly SCRIPT_NAME=$(basename "$0")
# shellcheck disable=SC2034
readonly CURRENT_MODULE_NAME="$SCRIPT_NAME"
readonly DEFAULT_SSH_PORT=22
readonly ALLOWED_PARAMS="r"

# Флаги режимов работы
RUN_FLAG=0  # Режим изменения порта

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
            r)  RUN_FLAG=1 ;;
            \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params" >&2 ;;
            :)  log_error "Параметр -$OPTARG требует значение" >&2 ;;
        esac
    done
}

# Получение активных портов SSH
_get_active_ssh_ports() {
    ss -tlnp | awk '/sshd/ && /LISTEN/ {split($4,a,":"); print a[length(a)]}' | sort -u
}

# Функция для сбора портов из конфигурационных файлов SSH
# Source: modules/ssh.txt
get_ssh_config_ports() {
    local main_config="/etc/ssh/sshd_config"
    local config_dir="/etc/ssh/sshd_config.d"
    local found_ports=()
    
    # Проверяем наличие основного конфига
    if [[ ! -f "$main_config" ]]; then
        echo "ОШИБКА: $main_config не найден!" >&2
        return 1
    fi
    
    # Обрабатываем основной конфиг
    # Ищем строки Port или ListenPort (с большой буквой!)
    # Игнорируем закомментированные строки
    while IFS= read -r line; do
        port=$(echo "$line" | awk '{print $2}')
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            found_ports+=("$port")
        fi
    done < <(grep -E "^[[:space:]]*(Port|ListenPort)[[:space:]]+" "$main_config" | \
             grep -v "^[[:space:]]*#")
    
    # Обрабатываем файлы из директории sshd_config.d/
    if [[ -d "$config_dir" ]]; then
        # ПРАВИЛЬНОЕ раскрытие glob - используем цикл для всех .conf файлов
        for conf_file in "$config_dir"/*.conf; do
            # Проверяем существование (glob может не найти файлы)
            if [[ -f "$conf_file" ]]; then
                
                while IFS= read -r line; do
                    port=$(echo "$line" | awk '{print $2}')
                    if [[ "$port" =~ ^[0-9]+$ ]]; then
                        found_ports+=("$port")
                    fi
                done < <(grep -E "^[[:space:]]*(Port|ListenPort)[[:space:]]+" "$conf_file" | \
                         grep -v "^[[:space:]]*#")
            fi
        done
    fi
    
    # Выводим уникальные порты
    if [[ ${#found_ports[@]} -gt 0 ]]; then
        printf "%s\n" "${found_ports[@]}" | sort -un
    else
        echo "ВНИМАНИЕ: Порты не найдены в файлах конфигурации" >&2
        echo "Это значит, что используется дефолтный порт 22" >&2
        return 1
    fi
}

# ========== ОСНОВНЫЕ ФУНКЦИИ ==========

# Режим проверки - собирает информацию о портах SSH
check() {
    local status
    local message
    local symbol
    local active_ssh_ports
    local config_ssh_ports
    local active_ports_formatted
    local config_ports_formatted
    
    # Получаем активные порты
    active_ssh_ports=$(_get_active_ssh_ports)
    
    # Получаем порты из конфигурации
    if config_ssh_ports=$(get_ssh_config_ports 2>/dev/null); then
        # Форматируем порты в виде "22,23,24" или "22"
        config_ports_formatted=$(echo "$config_ssh_ports" | tr '\n' ',' | sed 's/,$//')
    else
        # Если порты не найдены в конфигурации, используем порт 22 по умолчанию
        config_ports_formatted="$DEFAULT_SSH_PORT"
    fi
    
    # Форматируем активные порты
    if [[ -n "$active_ssh_ports" ]]; then
        active_ports_formatted=$(echo "$active_ssh_ports" | tr '\n' ',' | sed 's/,$//')
    else
        status=1
        message="SSH сервис не найден или не слушает порты"
        symbol="$SYMBOL_ERROR"
        
        # Вывод в Key-Value формате для парсинга через eval
        echo "message=\"$(printf '%s' "$message" | base64)\""
        echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
        echo "status=$status"
        echo "active_ssh_port="
        echo "config_files_ssh_port=$config_ports_formatted"
        return 1
    fi
    
    # Проверяем соответствие конфигурации и активных портов
    if [[ "$active_ports_formatted" == "$config_ports_formatted" ]]; then
        status=0
        message="SSH работает на портах: $active_ports_formatted"
        symbol="$SYMBOL_SUCCESS"
    else
        status=0
        message="SSH работает на портах: $active_ports_formatted (в конфигурации: $config_ports_formatted)"
        symbol="$SYMBOL_INFO"
    fi
    
    # Вывод в Key-Value формате для парсинга через eval
    echo "message=\"$(printf '%s' "$message" | base64)\""
    echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
    echo "status=$status"
    echo "active_ssh_port=$active_ports_formatted"
    echo "config_files_ssh_port=$config_ports_formatted"
    
    return "$status"
}

# Режим изменения порта - заглушка
run() {
    local status
    local message
    local symbol
    
    # Заглушка - всегда возвращает порт 22
    status=0
    message="Заглушка режима изменения порта. Текущий порт: 22"
    symbol="$SYMBOL_INFO"
    
    # Вывод в Key-Value формате для парсинга через eval
    echo "message=\"$(printf '%s' "$message" | base64)\""
    echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
    echo "status=$status"
    
    return "$status"
}

# ========== ОСНОВНАЯ ФУНКЦИЯ ==========

main() {
    # Если нет параметров, используем режим check по умолчанию
    if [[ "$#" -eq 0 ]]; then
        RUN_FLAG=0
    fi
    
    # Парсим параметры
    _parse_params "$ALLOWED_PARAMS" "$@"
    
    # Выполняем в зависимости от режима
    if [[ "$RUN_FLAG" -eq 1 ]]; then
        run
    else
        check
    fi
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
