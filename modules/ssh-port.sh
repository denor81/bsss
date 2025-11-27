#!/usr/bin/env bash

# Исходные данные
SSH_PORT_DEFAULT="22"
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
SSH_MAIN_CONFIG="/etc/ssh/sshd_config"

# Проверка текущего состояния SSH порта
check_ssh_port() {
    find_last_active_parameter "Port" "$SSH_MAIN_CONFIG" "$SSH_CONFIG_DIR"
}

# Создание файла конфигурации для SSH порта
create_ssh_port_config() {
    local port="$1"
    local index="$2"
    
    local filename="${SSH_CONFIG_DIR}/${index}-bsss-ssh-port.conf"
    
    check_write_permission "$SSH_CONFIG_DIR"
    
    cat > "$filename" << EOF
# SSH port configuration by BSSS
Port $port
EOF
    
    log_verbose "Создан файл конфигурации: $filename"
}

# Применение настроек SSH
apply_ssh_port_settings() {
    log_verbose "Применение настроек SSH..."
    
    if systemctl daemon-reload && systemctl restart ssh; then
        log_verbose "SSH сервис успешно перезапущен"
    else
        echo "Ошибка при перезапуске SSH сервиса" >&2
        exit 1
    fi
}

# Возврат к настройкам по умолчанию
restore_ssh_port_default() {
    log_verbose "Удаление файлов конфигурации SSH порта, созданных BSSS..."
    remove_bsss_files "$SSH_CONFIG_DIR" "ssh-port"
    apply_ssh_port_settings
}

# Основная функция модуля
ssh_port() {
    local mode="${1:-normal}"
    
    case "$mode" in
        --check)
            check_ssh_port
            ;;
        --default)
            restore_ssh_port_default
            ;;
        *)
            # Проверка текущего состояния
            local current_state
            current_state=$(check_ssh_port)
            
            if [[ "$current_state" != "notfound" ]]; then
                local current_port="${current_state%:*}"
                echo "Текущий SSH порт: $current_port"
                
                if confirm_yes_no "Хотите изменить SSH порт?"; then
                    local new_port
                    new_port=$(input_ssh_port)
                    
                    if [[ "$new_port" == "$current_port" ]]; then
                        echo "Новый порт совпадает с текущим. Изменения не требуются."
                        return 0
                    fi
                    
                    # Удаление старых файлов bsss
                    remove_bsss_files "$SSH_CONFIG_DIR" "ssh-port"
                    
                    # Определение индекса для нового файла
                    local index
                    index=$(generate_config_index "${current_state#*:}")
                    
                    # Создание нового файла конфигурации
                    create_ssh_port_config "$new_port" "$index"
                    
                    # Сохранение порта в глобальную переменную
                    SSH_PORT="$new_port"
                    
                    log_state_change "SSH порт" "$current_port" "$new_port"
                    apply_ssh_port_settings
                else
                    # Сохранение текущего порта в глобальную переменную
                    SSH_PORT="$current_port"
                fi
            else
                if confirm_yes_no "Хотите установить SSH порт?"; then
                    local new_port
                    new_port=$(input_ssh_port)
                    
                    # Создание директории если не существует
                    if [[ ! -d "$SSH_CONFIG_DIR" ]]; then
                        mkdir -p "$SSH_CONFIG_DIR"
                    fi
                    
                    # Создание файла конфигурации
                    create_ssh_port_config "$new_port" "10"
                    
                    # Сохранение порта в глобальную переменную
                    SSH_PORT="$new_port"
                    
                    log_state_change "SSH порт" "$SSH_PORT_DEFAULT" "$new_port"
                    apply_ssh_port_settings
                else
                    # Сохранение порта по умолчанию в глобальную переменную
                    SSH_PORT="$SSH_PORT_DEFAULT"
                fi
            fi
            ;;
    esac
}