#!/usr/bin/env bash

# Модуль загрузки конфигурации BSSS
# Отвечает за загрузку и предоставление доступа к конфигурационным параметрам

# Глобальная переменная для отслеживания загрузки конфигурации
declare -g CONFIG_LOADED=false

# Определение пути к конфигурационному файлу
readonly BSSS_CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/bsss.conf"

# Функция загрузки конфигурации
load_config() {
    if [[ "$CONFIG_LOADED" == true ]]; then
        return 0
    fi
    
    if [[ ! -f "$BSSS_CONFIG_FILE" ]]; then
        echo "Ошибка: конфигурационный файл не найден: $BSSS_CONFIG_FILE" >&2
        exit 1
    fi
    
    # Загрузка конфигурационного файла
    source "$BSSS_CONFIG_FILE"
    CONFIG_LOADED=true
    
    log_verbose "Конфигурация загружена из: $BSSS_CONFIG_FILE"
}

# Функция получения значения из конфигурации с проверкой загрузки
get_config() {
    local var_name="$1"
    
    # Автоматическая загрузка конфигурации, если она еще не загружена
    if [[ "$CONFIG_LOADED" != true ]]; then
        load_config
    fi
    
    # Проверка существования переменной
    if [[ -z "${!var_name:-}" ]]; then
        echo "Ошибка: конфигурационный параметр не найден: $var_name" >&2
        exit 1
    fi
    
    echo "${!var_name}"
}

# Функция проверки, что конфигурация загружена
is_config_loaded() {
    [[ "$CONFIG_LOADED" == true ]]
}

# Функция принудительной перезагрузки конфигурации
reload_config() {
    CONFIG_LOADED=false
    load_config
}