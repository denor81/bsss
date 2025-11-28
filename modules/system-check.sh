#!/usr/bin/env bash

# Загрузка конфигурации
source "${CACHE_BASE}/helpers/config-loader.sh"
load_config

# Получение конфигурационных параметров
REBOOT_REQUIRED_FILE="$(get_config REBOOT_REQUIRED_FILE)"

# Проверка необходимости перезагрузки системы
check_reboot_required() {
    if [[ -f "$REBOOT_REQUIRED_FILE" ]]; then
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