#!/usr/bin/env bash

# Проверка необходимости перезагрузки системы
check_reboot_required() {
    if [[ -f /var/run/reboot-required ]]; then
        echo "Требуется перезагрузка системы. Выполните перезагрузку и запустите скрипт снова."
        exit 1
    fi
}

# Основная функция модуля
system_check() {
    local mode="${1:-normal}"
    
    case "$mode" in
        --check)
            check_reboot_required
            ;;
        --default)
            # Нечего возвращать к настройкам по умолчанию для этого шага
            echo "Этот шаг не поддерживает режим --default"
            ;;
        *)
            check_reboot_required
            ;;
    esac
}