#!/usr/bin/env bash

# Загрузка конфигурации
source "${CACHE_BASE}/helpers/config-loader.sh"
load_config

# Получение конфигурационных параметров
GRUB_CONFIG_DIR="$(get_config GRUB_CONFIG_DIR)"
GRUB_MAIN_CONFIG="$(get_config GRUB_MAIN_CONFIG)"
GRUB_CMDLINE_PARAM="$(get_config GRUB_CMDLINE_PARAM)"
GRUB_IPV6_DISABLE_VALUE="$(get_config GRUB_IPV6_DISABLE_VALUE)"
GRUB_IPV6_CONFIG_PATTERN="$(get_config GRUB_IPV6_CONFIG_PATTERN)"
GRUB_UPDATE_COMMAND="$(get_config GRUB_UPDATE_COMMAND)"

# Проверка текущего состояния IPv6
check_ipv6_state() {
    local value=""
    local file=""
    
    # Проверка основного файла
    if [[ -f "$GRUB_MAIN_CONFIG" ]]; then
        value=$(grep -E "^\s*${GRUB_PARAM}\s*=.*ipv6\.disable=" "$GRUB_MAIN_CONFIG" | tail -1 | sed -E "s/^\s*${GRUB_PARAM}\s*=\s*\"([^\"]*)\".*/\1/")
        if [[ -n "$value" ]]; then
            file="$GRUB_MAIN_CONFIG"
        fi
    fi
    
    # Проверка файлов в .d директории
    if [[ -d "$GRUB_CONFIG_DIR" ]]; then
        while IFS= read -r -d '' config_file; do
            local file_value
            file_value=$(grep -E "^\s*${GRUB_PARAM}\s*=.*ipv6\.disable=" "$config_file" | tail -1 | sed -E "s/^\s*${GRUB_PARAM}\s*=\s*\"([^\"]*)\".*/\1/")
            if [[ -n "$file_value" ]]; then
                value="$file_value"
                file="$config_file"
            fi
        done < <(find "$GRUB_CONFIG_DIR" -name "*.conf" -type f -print0 | sort -z)
    fi
    
    if [[ -n "$value" ]]; then
        echo "${value}:${file}"
    else
        echo "notfound"
    fi
}

# Создание файла конфигурации для отключения IPv6
create_ipv6_config() {
    local index="$1"
    
    local filename="${GRUB_CONFIG_DIR}/${index}-${BSSS_CONFIG_PREFIX}-${GRUB_IPV6_CONFIG_PATTERN}${CONFIG_FILE_EXTENSION}"
    
    check_write_permission "$GRUB_CONFIG_DIR"
    
    cat > "$filename" << EOF
$BSSS_CONFIG_COMMENT
${GRUB_CMDLINE_PARAM}="${GRUB_IPV6_DISABLE_VALUE}"
EOF
    
    log_verbose "Создан файл конфигурации: $filename"
}

# Применение настроек GRUB
apply_ipv6_settings() {
    log_verbose "Применение настроек GRUB..."
    
    if "$GRUB_UPDATE_COMMAND"; then
        log_verbose "GRUB успешно обновлен"
    else
        echo "Ошибка при обновлении GRUB" >&2
        exit 1
    fi
}

# Возврат к настройкам по умолчанию
restore_ipv6_default() {
    log_verbose "Удаление файлов конфигурации IPv6, созданных BSSS..."
    remove_bsss_files "$GRUB_CONFIG_DIR" "$GRUB_IPV6_CONFIG_PATTERN"
    apply_ipv6_settings
}

# Основная функция модуля
ipv6_disable() {
    local mode="${1:-normal}"
    
    case "$mode" in
        --check)
            check_ipv6_state
            ;;
        --default)
            restore_ipv6_default
            ;;
        *)
            # Проверка текущего состояния
            local current_state
            current_state=$(check_ipv6_state)
            
            if [[ "$current_state" != "notfound" ]]; then
                local current_value="${current_state%:*}"
                
                if [[ "$current_value" == *"ipv6.disable=1"* ]]; then
                    echo "IPv6 уже отключен"
                else
                    echo "Текущее состояние IPv6: включен"
                    if confirm_yes_no "Хотите отключить IPv6?"; then
                        # Удаление старых файлов bsss
                        remove_bsss_files "$GRUB_CONFIG_DIR" "$GRUB_IPV6_CONFIG_PATTERN"
                        
                        # Определение индекса для нового файла
                        local index
                        index=$(generate_config_index "${current_state#*:}")
                        
                        # Создание директории если не существует
                        if [[ ! -d "$GRUB_CONFIG_DIR" ]]; then
                            mkdir -p "$GRUB_CONFIG_DIR"
                        fi
                        
                        # Создание нового файла конфигурации
                        create_ipv6_config "$index"
                        
                        log_state_change "IPv6" "включен" "отключен"
                        apply_ipv6_settings
                    fi
                fi
            else
                echo "Текущее состояние IPv6: включен (настроек не найдено)"
                if confirm_yes_no "Хотите отключить IPv6?"; then
                    # Создание директории если не существует
                    if [[ ! -d "$GRUB_CONFIG_DIR" ]]; then
                        mkdir -p "$GRUB_CONFIG_DIR"
                    fi
                    
                    # Создание файла конфигурации
                    create_ipv6_config "$CONFIG_DEFAULT_INDEX"
                    
                    log_state_change "IPv6" "включен" "отключен"
                    apply_ipv6_settings
                fi
            fi
            ;;
    esac
}