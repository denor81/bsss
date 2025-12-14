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
# shellcheck disable=SC2155
readonly CURRENT_MODULE_NAME="$(basename "$0")"
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
# TESTED: tests/test_ssh-port_parse_params.sh
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
# TESTED: tests/test_ssh-port_get_active_ssh_ports.sh
_get_active_ssh_ports() {
    ss -tlnp | awk '/sshd/ && /LISTEN/ {split($4,a,":"); print a[length(a)]}' | sort -u
}

# Вспомогательная функция для извлечения портов из файла конфигурации
# TESTED: tests/test_ssh-port_extract_ports_from_file.sh
_extract_ports_from_file() {
    local config_file="${1:-}"
    local found_ports=()
    
    if [[ ! -f "$config_file" ]]; then
        return 0
    fi
    
    # Ищем строки Port или ListenPort (с большой буквой!)
    # Игнорируем закомментированные строки
    while IFS= read -r line; do
        port=$(echo "$line" | awk '{print $2}')
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            found_ports+=("$port")
        fi
    done < <(grep -E "^[[:space:]]*(Port|ListenPort)[[:space:]]+" "$config_file" 2>/dev/null | \
             grep -v "^[[:space:]]*#")
    
    # Выводим найденные порты
    if [[ ${#found_ports[@]} -gt 0 ]]; then
        printf "%s\n" "${found_ports[@]}"
    fi
}

# Функция для сбора портов из конфигурационных файлов SSH
# TESTED: tests/test_ssh-port_get_ssh_config_ports.sh
get_ssh_config_ports() {
    local main_config="${1:-/etc/ssh/sshd_config}"
    local config_dir="${2:-/etc/ssh/sshd_config.d}"
    local found_ports=()
    local ports_from_file
    
    # Обрабатываем основной конфиг
    ports_from_file=$(_extract_ports_from_file "$main_config")
    if [[ -n "$ports_from_file" ]]; then
        while IFS= read -r port; do
            found_ports+=("$port")
        done <<< "$ports_from_file"
    fi
    
    # Обрабатываем файлы из директории sshd_config.d/
    if [[ -d "$config_dir" ]]; then
        # ПРАВИЛЬНОЕ раскрытие glob - используем цикл для всех .conf файлов
        for conf_file in "$config_dir"/*.conf; do
            # Проверяем существование (glob может не найти файлы)
            if [[ -f "$conf_file" ]]; then
                ports_from_file=$(_extract_ports_from_file "$conf_file")
                if [[ -n "$ports_from_file" ]]; then
                    while IFS= read -r port; do
                        found_ports+=("$port")
                    done <<< "$ports_from_file"
                fi
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

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ ПРОВЕРКИ КОНФИГУРАЦИИ ==========

# ADAPTATED FOR TESTS: 14/12/24
# Проверяет наличие конфигурационных файлов SSH
check_ssh_config_exists() {
    # Параметризация для тестирования
    local config_dir="${1:-$SSH_CONFIG_DIR}"
    local config_mask="${2:-$SSH_CONFIG_FILE_MASK}"
    local found_files
    
    # Ищем файлы по маске
    found_files=$(find "$config_dir" -type f -iname "$config_mask" 2>/dev/null)
    
    if [[ -z "$found_files" ]]; then
        return 1  # Файлы не найдены
    else
        log_info_simple_tab "Найден(ы) конфиг(и)"
        for file in $found_files; do
            log_info_simple_tab "$file [$(grep -iE '^port' "$file")]"
        done
        return 0  # Файлы найдены
    fi
}

# Предлагает пользователю выбор между сбросом и изменением порта
ask_user_reset_or_change() {
    local input_source="${1:-/dev/tty}"                    # Источник ввода (по умолчанию /dev/tty)
    local symbol_question="${2:-$SYMBOL_QUESTION}"         # Символ вопроса
    local module_name="${3:-${CURRENT_MODULE_NAME:-04-ssh-port}}"  # Имя модуля
    
    local choice=""
    local valid_choice=false
    
    while [[ "$valid_choice" == "false" ]]; do
        # Получаем данные из указанного источника ввода
        # В теории может быть несколько файлов BSSS, на практике же один файл
        log_info_simple_tab "1. По умолчанию - означает удаление конфиг файлов BSSS для SSH
            порта (другие настройки не трогаются) - будет задействован стандартный порт 22
            или другой порт, если присутствуют другие настройки в /etc/ssh/ директории."
        log_info_simple_tab "2. Переустановить порт - означает, что будут удалены конфиг файл(ы) BSSS для SSH
            и создан новый файл с новым указанным портом - он и будет действовать."
        log_info_simple_tab "Актуальная информация отображается в информационном блоке при запуске BSSS."
        read -p "$symbol_question [$module_name] Введите 1 или 2: " -r choice < "$input_source"
        
        # Обработка пустого ввода (по умолчанию 2)
        if [[ -z "$choice" ]]; then
            choice="2"
        fi
        
        # Проверка корректности ввода
        if [[ "$choice" == "1" ]]; then
            echo "reset"
            valid_choice=true
        elif [[ "$choice" == "2" ]]; then
            echo "change"
            valid_choice=true
        else
            log_error "Некорректный выбор. Введите 1 или 2"
        fi
    done
}

# Выполняет сброс настроек SSH к значениям по умолчанию
restore_default() {
    # log_info "Сбрасываю настройки SSH к значениям по умолчанию..."
    
    # Шаг 1: Удаляем старые конфигурационные файлы
    remove_old_ssh_config_files || return 1
    
    # Шаг 2: Перезапускаем SSH сервис
    restart_ssh_service || return 1
    
    # Шаг 3: Проверяем результат изменений
    check 1 || return 1
    
    # log_success "Настройки SSH успешно сброшены к значениям по умолчанию (порт 22)"
    return 0
}

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ СМЕНЫ ПОРТА ==========

# ADAPTATED FOR TESTS: 14/12/24
# НЕ МОЖЕТ БЫТЬ КОРРЕКТНО ПРОТЕСТИРОВАН ИЗ ЗА ОЖИДАНИЯ ВВОДА ОТ /dev/tty
# Функция для ввода порта от пользователя с валидацией
ask_user_for_port() {
    # Параметризация для тестирования
    local input_source="${1:-/dev/tty}"                    # Источник ввода (по умолчанию /dev/tty)
    local symbol_question="${2:-$SYMBOL_QUESTION}"         # Символ вопроса
    local module_name="${3:-${CURRENT_MODULE_NAME:-04-ssh-port}}"  # Имя модуля
    
    local port=""
    local valid_port=false
    
    while [[ "$valid_port" == "false" ]]; do
        # Выводим сообщение через библиотеку логирования
        # log_info "Введите номер порта для SSH (1-65535):"

        # Получаем данные из указанного источника ввода
        read -p "$symbol_question [$module_name] Введите номер порта для SSH (1-65535): " -r port < "$input_source"
        
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
        # if [[ "$port" -lt 1024 ]]; then
            # log_info "Порт $port является привилегированным (< 1024)"
            # log_info "Убедитесь, что SSH имеет права на использование этого порта"
        # fi
        
        # Проверка занятости порта
        if is_port_in_use "$port"; then
            log_error "Порт $port уже используется другим процессом"
            log_info "Проверьте, какой процесс использует порт: ss -nlptu | grep :$port"
            continue
        fi
        
        valid_port=true
    done
    
    echo "$port"
}

# Проверка занятости порта
# НЕ МОЖЕТ БЫТЬ КОРРЕКТНО ПРОТЕСТИРОВАН
is_port_in_use() {
    local port="${1:-}"
    
    if ss -tlnp | grep -q ":$port "; then
        return 0  # Порт занят
    else
        return 1  # Порт свободен
    fi
}

# Поиск и удаление старых конфигурационных файлов
# TESTED: tests/test_ssh-port_remove_old_ssh_config_files.sh
remove_old_ssh_config_files() {
    local config_dir="${1:-$SSH_CONFIG_DIR}"
    local config_mask="${2:-$SSH_CONFIG_FILE_MASK}"
    local found_files
    local removed_count=0
    
    # Ищем файлы по маске
    found_files=$(find "$config_dir" -type f -iname "$config_mask" 2>/dev/null || true)
    
    if [[ -z "$found_files" ]]; then
        # log_info "Старые конфигурационные файлы SSH не найдены"
        return 0
    fi
    
    # log_info "Найдены старые конфигурационные файлы:"
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            # log_info "  - $file"
            local port=$(grep -iE '^port' "$file")
            if rm -f "$file"; then
                log_info "Удален файл: $file [$port]"
                ((removed_count++))
            else
                log_error "Не удалось удалить файл: $file"
            fi
        fi
    done <<< "$found_files"
    
    # if [[ $removed_count -gt 0 ]]; then
        # log_success "Удалено $removed_count старых конфигурационных файлов"
    # fi
    
    return 0
}

# Создание нового конфигурационного файла
# TESTED: tests/test_ssh-port_create_new_ssh_config_file.sh
create_new_ssh_config_file() {
    local port="${1:-}"
    local config_dir="${2:-$SSH_CONFIG_DIR}"
    local config_file="${3:-$SSH_CONFIG_FILE}"
    local config_path="$config_dir/$config_file"
    
    if [[ -z "$port" ]]; then
        log_error "Не указан порт для конфигурационного файла"
        return 1
    fi
    
    # log_info "Создаю конфигурационный файл: $config_path"
    
    # Создаем файл с настройкой порта
    if cat > "$config_path" << EOF
# Generated by bsss
# SSH port configuration
Port $port
EOF
    then
        log_success "Конфиг создан: $config_path [$(grep -iE '^port' "$config_path")]"
        # log_info "SSH будет слушать на порту: $port"
        return 0
    else
        log_error "Не удалось создать конфигурационный файл: $config_path"
        return 1
    fi
}

# Перезапуск SSH сервиса
restart_ssh_service() {
    log_info "Перезагружаю конфигурацию [systemctl daemon-reload]"
    systemctl daemon-reload || return 1
    
    log_info "Перезапускаю SSH сервис [systemctl restart ssh]"
    systemctl restart ssh || return 1
    
    # log_success "SSH сервис успешно перезапущен"
    return 0
}

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ ПРОВЕРКИ ПОРТОВ ==========

# Сбор данных о портах SSH
# TESTED: tests/test_ssh-port_collect_ssh_ports_data.sh
_collect_ssh_ports_data() {
    local default_ssh_port="${1:-$DEFAULT_SSH_PORT}"
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
    fi
    
    # Форматируем активные порты
    if [[ -n "$active_ssh_ports" ]]; then
        active_ports_formatted=$(echo "$active_ssh_ports" | tr '\n' ',' | sed 's/,$//')
    else
        active_ports_formatted=""
    fi
    
    # Возвращаем данные через глобальные переменные
    COLLECTED_ACTIVE_PORTS="$active_ports_formatted"
    COLLECTED_CONFIG_PORTS="${config_ports_formatted:-}"
}

# TESTED: tests/test_ssh-port_format_user_output.sh
# Форматирование вывода для пользователя
_format_user_output() {
    local status="$1"
    local message="$2"
    local symbol="$3"
    
    log_info "$message" "$symbol"
    return "$status"
}

# Форматирование вывода для парсинга через eval
_format_eval_output() {
    local status="$1"
    local message="$2"
    local symbol="$3"
    local active_ports="$4"
    local config_ports="$5"
    
    echo "message=\"$(printf '%s' "$message" | base64)\""
    echo "symbol=\"$(printf '%s' "$symbol" | base64)\""
    echo "status=$status"
    echo "active_ssh_port=$active_ports"
    echo "config_files_ssh_port=$config_ports"
    return "$status"
}

# ========== ОСНОВНЫЕ ФУНКЦИИ ==========

# Режим проверки - собирает информацию о портах SSH
# TESTED: tests/test_check.sh
check() {
    local out_msg_type="${1:-0}"  # 0 - для парсинга через eval, 1 - для вывода пользователю
    local default_ssh_port="${2:-$DEFAULT_SSH_PORT}"
    
    local status
    local message
    local symbol
    local active_ports
    local config_ports
    
    # Собираем данные о портах
    _collect_ssh_ports_data "$default_ssh_port"
    active_ports="$COLLECTED_ACTIVE_PORTS"
    config_ports="$COLLECTED_CONFIG_PORTS"
    
    # Проверяем наличие активных портов
    if [[ -z "$active_ports" ]]; then
        status=1
        message="SSH сервис не найден или не слушает порты"
        symbol="$SYMBOL_ERROR"
    else
        status=0
        message="SSH работает на портах: $active_ports (в конфигурации: ${config_ports:-нет активной настройки})"
        symbol="$SYMBOL_INFO"
    fi
    
    # Форматируем вывод в зависимости от типа
    if [[ "$out_msg_type" -eq 1 ]]; then
        _format_user_output "$status" "$message" "$symbol"
    else
        _format_eval_output "$status" "$message" "$symbol" "$active_ports" "$config_ports"
    fi
    
    return "$status"
}

# Режим изменения порта
run() {
    local new_port
    local user_choice
    
    # Шаг 1: Проверяем наличие существующих конфигурационных файлов
    if check_ssh_config_exists; then
        # Шаг 2: Если файлы существуют, предлагаем выбор пользователю
        user_choice=$(ask_user_reset_or_change)
        
        # Шаг 3: Обрабатываем выбор пользователя
        if [[ "$user_choice" == "reset" ]]; then
            # Сбрасываем настройки на значения по умолчанию
            restore_default
            return $?
        fi
        # Если выбор "change", продолжаем с обычной сменой порта
    fi
    
    # Шаг 4: Получаем порт от пользователя с валидацией
    new_port=$(ask_user_for_port)
    if [[ $? -ne 0 || -z "$new_port" ]]; then
        return 1
    fi
    
    # Шаг 5: Удаляем старые конфигурационные файлы
    remove_old_ssh_config_files || return 1
    
    # Шаг 6: Создаем новый конфигурационный файл
    create_new_ssh_config_file "$new_port" || return 1
    
    # Шаг 7: Перезапускаем SSH сервис
    restart_ssh_service || return 1
    
    # Шаг 8: Проверяем результат изменений
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
