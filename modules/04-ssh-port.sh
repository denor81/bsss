#!/usr/bin/env bash
# 04-ssh-port.sh
# Четвертый модуль системы
# Проверяет и изменяет SSH порт
# Usage: ./04-ssh-port.sh [-r]
#   -r  Режим изменения порта
# MODULE_TYPE: check-and-run

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
readonly SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
readonly SSH_CONFIG_FILE_MASK="*bsss-ssh-port.conf"
readonly SSH_CONFIG_FILE="10-bsss-ssh-port.conf"

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
            \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params" ;;
            :)  log_error "Параметр -$OPTARG требует значение" ;;
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
    
    # Обрабатываем основной конфиг
    # Ищем строки Port или ListenPort (с большой буквой!)
    # Игнорируем закомментированные строки
    while IFS= read -r line; do
        port=$(echo "$line" | awk '{print $2}')
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            found_ports+=("$port")
        fi
    done < <(grep -E "^[[:space:]]*(Port|ListenPort)[[:space:]]+" "$main_config" 2>/dev/null | \
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
        log_info "Порты не найдены в файлах конфигурации"
        log_info "Это значит, что используется дефолтный порт 22"
        return 1
    fi
}

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ СМЕНЫ ПОРТА ==========

# Функция для ввода порта от пользователя с валидацией
ask_user_for_port() {
    local port
    local valid_port=false
    
    while [[ "$valid_port" == "false" ]]; do
        # Выводим сообщение через библиотеку логирования
        log_info "Введите номер порта для SSH (1-65535):"

        # Получаем данные напрмую из терминала < /dev/tty
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] Порт: " -r port < /dev/tty
        
        # Проверка, что введено число
        if [[ ! "$port" =~ ^[0-9]+$ ]]; then
            log_error "Порт должен быть числом"
            continue
        fi
        
        # Проверка диапазона портов
        if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
            log_error "Порт должен быть в диапазоне от 1 до 65535"
            continue
        fi
        
        # Предупреждение для привилегированных портов (< 1024)
        if [[ "$port" -lt 1024 ]]; then
            log_info "Порт $port является привилегированным (< 1024)"
            log_info "Убедитесь, что SSH имеет права на использование этого порта"
        fi
        
        # Проверка занятости порта
        if is_port_in_use "$port"; then
            log_error "Порт $port уже используется другим процессом"
            log_info "Проверьте, какой процесс использует порт: ss -tlnp | grep :$port"
            continue
        fi
        
        valid_port=true
    done
    
    echo "$port"
}

# Проверка занятости порта
is_port_in_use() {
    local port="${1:-}"
    
    if ss -tlnp | grep -q ":$port "; then
        return 0  # Порт занят
    else
        return 1  # Порт свободен
    fi
}

# Поиск и удаление старых конфигурационных файлов
remove_old_ssh_config_files() {
    local config_dir="${1:-$SSH_CONFIG_DIR}"
    local config_mask="${2:-$SSH_CONFIG_FILE_MASK}"
    local found_files
    local removed_count=0
    
    # Ищем файлы по маске
    found_files=$(find "$config_dir" -type f -iname "$config_mask" 2>/dev/null || true)
    
    if [[ -z "$found_files" ]]; then
        log_info "Старые конфигурационные файлы SSH не найдены"
        return 0
    fi
    
    log_info "Найдены старые конфигурационные файлы:"
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            log_info "  - $file"
            if rm -f "$file"; then
                log_success "Удален файл: $file"
                ((removed_count++))
            else
                log_error "Не удалось удалить файл: $file"
            fi
        fi
    done <<< "$found_files"
    
    if [[ $removed_count -gt 0 ]]; then
        log_success "Удалено $removed_count старых конфигурационных файлов"
    fi
    
    return 0
}

# Создание нового конфигурационного файла
create_new_ssh_config_file() {
    local port="${1:-}"
    local config_dir="${2:-$SSH_CONFIG_DIR}"
    local config_file="${3:-$SSH_CONFIG_FILE}"
    local config_path="$config_dir/$config_file"
    
    if [[ -z "$port" ]]; then
        log_error "Не указан порт для конфигурационного файла"
        return 1
    fi
    
    log_info "Создаю конфигурационный файл: $config_path"
    
    # Создаем файл с настройкой порта
    if cat > "$config_path" << EOF
# Generated by bsss
# SSH port configuration
Port $port
EOF
    then
        log_success "Конфигурационный файл создан: $config_path"
        log_info "SSH будет слушать на порту: $port"
        return 0
    else
        log_error "Не удалось создать конфигурационный файл: $config_path"
        return 1
    fi
}

# Перезапуск SSH сервиса
restart_ssh_service() {
    log_info "Перезагружаю конфигурацию systemd..."
    systemctl daemon-reload || return 1
    
    log_info "Перезапускаю SSH сервис..."
    systemctl restart ssh || return 1
    
    log_success "SSH сервис успешно перезапущен"
    return 0
}

# ========== ОСНОВНЫЕ ФУНКЦИИ ==========

# Режим проверки - собирает информацию о портах SSH
check() {
    local out_msg_type="${1:-0}"  # 0 - для парсинга через eval, 1 - для вывода пользователю
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
        
        if [[ "$out_msg_type" -eq 1 ]]; then
            # Вывод для пользователя
            echo "$symbol $message"
            return 1
        else
            # Вывод в Key-Value формате для парсинга через eval
            echo "message=\"$(printf '%s' "$message" | base64)\""
            echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
            echo "status=$status"
            echo "active_ssh_port="
            echo "config_files_ssh_port=$config_ports_formatted"
            return 1
        fi
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
    
    if [[ "$out_msg_type" -eq 1 ]]; then
        # Вывод для пользователя
        echo "$symbol $message"
    else
        # Вывод в Key-Value формате для парсинга через eval
        echo "message=\"$(printf '%s' "$message" | base64)\""
        echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
        echo "status=$status"
        echo "active_ssh_port=$active_ports_formatted"
        echo "config_files_ssh_port=$config_ports_formatted"
    fi
    
    return "$status"
}

# Режим изменения порта
run() {
    local new_port
    
    # Шаг 1: Получаем порт от пользователя с валидацией
    new_port=$(ask_user_for_port)
    if [[ $? -ne 0 || -z "$new_port" ]]; then
        return 1
    fi
    
    # Шаг 2: Удаляем старые конфигурационные файлы
    remove_old_ssh_config_files || return 1
    
    # Шаг 3: Создаем новый конфигурационный файл
    create_new_ssh_config_file "$new_port" || return 1
    
    # Шаг 4: Перезапускаем SSH сервис
    restart_ssh_service || return 1
    
    # Шаг 5: Проверяем результат изменений
    check 1
    
    # Успешное завершение
    return 0
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
        # В режиме изменений выполняем действия и возвращаем только код возврата
        run
    else
        # В режиме проверки выводим информацию в stdout для парсинга основным скриптом
        check
    fi
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
