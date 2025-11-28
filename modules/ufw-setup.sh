#!/usr/bin/env bash

# Загрузка конфигурации
source "${CACHE_BASE}/helpers/config-loader.sh"
load_config

# Получение конфигурационных параметров
SSH_SERVICE_NAME="$(get_config SSH_SERVICE_NAME)"
UFW_SERVICE_NAME="$(get_config UFW_SERVICE_NAME)"
UFW_DEFAULT_POLICY="$(get_config UFW_DEFAULT_POLICY)"
UFW_SSH_PROTOCOL="$(get_config UFW_SSH_PROTOCOL)"
SSH_PORT_DEFAULT="$(get_config SSH_PORT_DEFAULT)"
STATUS_ACTIVE="$(get_config STATUS_ACTIVE)"
STATUS_INACTIVE="$(get_config STATUS_INACTIVE)"

# Получение текущего SSH порта
get_current_ssh_port() {
    # Если SSH порт уже установлен в глобальной переменной, используем его
    if [[ -n "$SSH_PORT" ]]; then
        echo "$SSH_PORT"
        return 0
    fi
    
    # Иначе получаем порт из ssh-port модуля
    local ssh_port_result
    ssh_port_result=$(ssh_port --check)
    
    if [[ "$ssh_port_result" != "notfound" ]]; then
        local port="${ssh_port_result%:*}"
        echo "$port"
    else
        echo "$SSH_PORT_DEFAULT"  # Порт по умолчанию
    fi
}

# Настройка UFW
setup_ufw() {
    local ssh_port
    ssh_port=$(get_current_ssh_port)
    
    log_verbose "Настройка UFW для SSH порта: $ssh_port"
    
    # Разрешение SSH порта
    if ufw allow "${ssh_port}/${UFW_SSH_PROTOCOL}"; then
        log_verbose "SSH порт $ssh_port разрешен в UFW"
    else
        echo "Ошибка при разрешении SSH порта в UFW" >&2
        exit 1
    fi
    
    # Установка политики по умолчанию для входящих соединений
    if ufw default "$UFW_DEFAULT_POLICY" incoming; then
        log_verbose "Установлена политика $UFW_DEFAULT_POLICY incoming по умолчанию"
    else
        echo "Ошибка при установке политики по умолчанию" >&2
        exit 1
    fi
    
    # Активация UFW
    if ufw --force enable; then
        log_verbose "UFW успешно активирован"
    else
        echo "Ошибка при активации UFW" >&2
        exit 1
    fi
}

# Отключение UFW
disable_ufw() {
    log_verbose "Отключение UFW..."
    
    if ufw --force disable; then
        log_verbose "UFW успешно отключен"
    else
        echo "Ошибка при отключении UFW" >&2
        exit 1
    fi
}

# Проверка текущего состояния UFW
check_ufw_status() {
    if ufw status | grep -q "Status: $STATUS_ACTIVE"; then
        echo "$STATUS_ACTIVE"
    else
        echo "$STATUS_INACTIVE"
    fi
}

# Основная функция модуля
ufw_setup() {
    local mode="${1:-normal}"
    
    case "$mode" in
        --check)
            check_ufw_status
            ;;
        --default)
            disable_ufw
            ;;
        *)
            local current_status
            current_status=$(check_ufw_status)
            
            if [[ "$current_status" == "$STATUS_ACTIVE" ]]; then
                echo "UFW уже активен"
            else
                echo "Текущее состояние UFW: неактивен"
                if confirm_yes_no "Хотите активировать UFW?"; then
                    setup_ufw
                    log_state_change "UFW" "неактивен" "активен"
                fi
            fi
            ;;
    esac
}