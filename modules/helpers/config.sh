#!/usr/bin/env bash

# Поиск последнего активного параметра в конфигурационных файлах
find_last_active_parameter() {
    local param_name="$1"
    local main_config="$2"
    local config_dir="$3"
    
    local last_value=""
    local last_file=""
    
    # Проверка основного файла
    if [[ -f "$main_config" ]]; then
        last_value=$(grep -E "^\s*${param_name}\s+" "$main_config" | tail -1 | awk '{print $2}')
        if [[ -n "$last_value" ]]; then
            last_file="$main_config"
        fi
    fi
    
    # Проверка файлов в .d директории
    if [[ -d "$config_dir" ]]; then
        find "$config_dir" -name "*.conf" -type f | sort | while read -r config_file; do
            local file_value
            file_value=$(grep -E "^\s*${param_name}\s+" "$config_file" | tail -1 | awk '{print $2}')
            if [[ -n "$file_value" ]]; then
                last_value="$file_value"
                last_file="$config_file"
            fi
            echo "Debug: Processing file: $config_file, value: $file_value"
        done
    fi
    
    if [[ -n "$last_value" ]]; then
        echo "${last_value}:${last_file}"
    else
        echo "notfound"
    fi
}

# Генерация индекса для нового файла конфигурации
generate_config_index() {
    local last_file="$1"
    local default_index="10"
    local max_index="99"
    
    if [[ "$last_file" == "notfound" ]]; then
        echo "$default_index"
        return
    fi
    
    # Извлечение индекса из имени файла
    local basename
    basename=$(basename "$last_file")
    local index
    index=$(echo "$basename" | sed -E 's/^([0-9]+).*/\1/')
    
    if [[ -n "$index" && "$index" =~ ^[0-9]+$ ]]; then
        local new_index=$((index + 10))
        # Ограничение максимального индекса
        if ((new_index > max_index)); then
            echo "$max_index"
        else
            echo "$new_index"
        fi
    else
        echo "$default_index"
    fi
}

# Удаление файлов bsss для указанного параметра
remove_bsss_files() {
    local config_dir="$1"
    local param_pattern="$2"
    
    if [[ -d "$config_dir" ]]; then
        find "$config_dir" -name "*bsss*${param_pattern}*.conf" -type f -delete
    fi
}