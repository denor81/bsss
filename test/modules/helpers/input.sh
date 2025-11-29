#!/usr/bin/env bash

# Загрузка конфигурации
source "${CACHE_BASE}/helpers/config-loader.sh"
load_config

# Получение конфигурационных параметров
PORT_MIN="$(get_config PORT_MIN)"
PORT_MAX="$(get_config PORT_MAX)"

# Функция подтверждения Y/n с Y по умолчанию
confirm_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "${prompt} [Y/n]: " response
        response=${response:-Y}
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Пожалуйста, введите Y или n"
                ;;
        esac
    done
}

# Ввод и валидация SSH порта
input_ssh_port() {
    local port
    while true; do
        read -p "Введите SSH порт (1-65535): " port
        
        # Удаление пробелов
        port=$(echo "$port" | tr -d ' ')
        
        # Проверка что это число и в допустимом диапазоне
        if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= PORT_MIN && port <= PORT_MAX)); then
            echo "$port"
            return 0
        else
            echo "Ошибка: порт должен быть числом от $PORT_MIN до $PORT_MAX"
        fi
    done
}