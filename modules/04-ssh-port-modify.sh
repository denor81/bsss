#!/usr/bin/env bash
# Изменяет SSH порт
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"
source "${MODULES_DIR_PATH}/../lib/user_confirmation.sh"
source "${MODULES_DIR_PATH}/common-helpers.sh"
source "${MODULES_DIR_PATH}/04-ssh-port-helpers.sh"

_dispatch_logic() {
    local raw_paths

    raw_paths=$(_get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK")

    if [[ -z "$raw_paths" ]]; then
        _branch_bsss_not_exists
    else
        _branch_bsss_exists "$raw_paths"
    fi
}

_branch_bsss_not_exists() {
    log_info "_branch_bsss_not_exists"
}

_branch_bsss_exists() {
    local raw_paths="$1"
    local user_action
    local -a paths=()

    mapfile -t paths < <(printf '%s' "$raw_paths")

    log_info "Найдена конфигурация ${UTIL_NAME^^}:"

    for path in "${paths[@]}"; do
        log_info_simple_tab "Путь: $path"
    done

    log_info_simple_tab "1. Сброс (удаление файлов BSSS, возврат к порту по умолчанию)"
    log_info_simple_tab "2. Переустановка (замена на новый порт)"

    user_action=$(_ask_value "Выберите" "" "^[12]$" "1/2") || return "$?"

    case "$user_action" in
        1) _action_restore_default "$raw_paths" ;;
        2) _action_reinstall_port "$raw_paths" ;;
    esac
}

_action_restore_default() {
    local raw_paths="$1"

    _delete_paths "$raw_paths"
    restart_services
    check_active_ports
    check_config_ports
    check_bsss_configs
}

_action_reinstall_port() {
    local raw_paths="$1"
    local new_port

    new_port=$(_ask_value "Введите новый порт" "" "^[0-9]+$" "1-65535")
}

restart_services() {
    systemctl daemon-reload && log_info "Конфигурация перезагружена [systemctl daemon-reload]"
    systemctl restart ssh && log_info "SSH сервис перезагружен [systemctl restart ssh]"
}












# Выполняет сброс настроек SSH к значениям по умолчанию
restore_default() {
    remove_old_ssh_config_files
    restart_services
    check 1
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
        log_info "Конфиг создан: $config_path [$(grep -iE '^port' "$config_path")]"
        # log_info "SSH будет слушать на порту: $port"
        return 0
    else
        log_error "Не удалось создать конфигурационный файл: $config_path"
        return 1
    fi
}

# Перезапуск SSH сервиса


# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ ПРОВЕРКИ ПОРТОВ ==========

# Сбор данных о портах SSH
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
    else
        # Если порты не найдены в конфигурации, используем порт по умолчанию
        config_ports_formatted="$default_ssh_port"
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
    echo "END"
    return "$status"
}

# ========== ОСНОВНЫЕ ФУНКЦИИ ==========

# Режим проверки - собирает информацию о портах SSH
check() {
    # Отдельный режим 1 для прмого логирования в терминал 
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
        message="SSH сервис не распознан или не слушает порты"
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
        # _format_eval_output "$status" "$message" "$symbol" "$active_ports" "$config_ports"
        log_info "$message"
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
    remove_old_ssh_config_files
    
    # Шаг 6: Создаем новый конфигурационный файл
    create_new_ssh_config_file "$new_port"
    
    # Шаг 7: Перезапускаем SSH сервис
    restart_services
    
    # Шаг 8: Проверяем результат изменений
    check 1
    
    # Успешное завершение
    return 0
}

run_modify() {
    run_confirm
}

check() {
    log_info "Текущие активные SSH порты: $(_get_active_ssh_ports)"
    log_info "Основной конфиг файл: $SSH_CONFIG_FILE"
    log_info "Список правил: $(_get_paths_by_mask "$SSH_CONFIGD_DIR" "$SSH_CONFIG_FILE_MASK")"
    ask_user_reset_or_change
}

main() {
    _dispatch_logic
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
