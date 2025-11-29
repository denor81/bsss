#!/usr/bin/env bash

# Обновление системы
update_system() {
    log_verbose "Обновление пакетов системы..."
    
    if apt update && apt upgrade -y; then
        log_verbose "Система успешно обновлена"
    else
        echo "Ошибка при обновлении системы" >&2
        exit 1
    fi
}

# Основная функция модуля
system_update() {
    local mode="${1:-normal}"
    
    case "$mode" in
        --check)
            echo "notfound"
            ;;
        --default)
            # Нечего возвращать к настройкам по умолчанию для этого шага
            echo "Этот шаг не поддерживает режим --default"
            ;;
        *)
            update_system
            ;;
    esac
}