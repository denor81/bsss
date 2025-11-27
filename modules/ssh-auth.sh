#!/usr/bin/env bash

# Исходные данные
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
SSH_MAIN_CONFIG="/etc/ssh/sshd_config"
SSH_PARAM="PasswordAuthentication"
SSH_VALUE="no"

# Проверка текущего состояния авторизации по паролю
check_password_auth() {
    local value=""
    local file=""
    
    # Проверка основного файла
    if [[ -f "$SSH_MAIN_CONFIG" ]]; then
        value=$(grep -E "^\s*${SSH_PARAM}\s+(yes|no)" "$SSH_MAIN_CONFIG" | tail -1 | awk '{print $2}')
        if [[ -n "$value" ]]; then
            file="$SSH_MAIN_CONFIG"
        fi
    fi
    
    # Проверка файлов в .d директории
    if [[ -d "$SSH_CONFIG_DIR" ]]; then
        while IFS= read -r -d '' config_file; do
            local file_value
            file_value=$(grep -E "^\s*${SSH_PARAM}\s+(yes|no)" "$config_file" | tail -1 | awk '{print $2}')
            if [[ -n "$file_value" ]]; then
                value="$file_value"
                file="$config_file"
            fi
        done < <(find "$SSH_CONFIG_DIR" -name "*.conf" -type f -print0 | sort -z)
    fi
    
    if [[ -n "$value" ]]; then
        echo "${value}:${file}"
    else
        echo "notfound"
    fi
}

# Создание файла конфигурации для отключения авторизации по паролю
create_ssh_auth_config() {
    local index="$1"
    
    local filename="${SSH_CONFIG_DIR}/${index}-bsss-disable-pass-auth.conf"
    
    check_write_permission "$SSH_CONFIG_DIR"
    
    cat > "$filename" << EOF
# SSH password authentication disable by BSSS
${SSH_PARAM} ${SSH_VALUE}
EOF
    
    log_verbose "Создан файл конфигурации: $filename"
}

# Применение настроек SSH
apply_ssh_auth_settings() {
    log_verbose "Применение настроек SSH..."
    
    if systemctl daemon-reload && systemctl restart ssh; then
        log_verbose "SSH сервис успешно перезапущен"
    else
        echo "Ошибка при перезапуске SSH сервиса" >&2
        exit 1
    fi
}

# Возврат к настройкам по умолчанию
restore_ssh_auth_default() {
    log_verbose "Удаление файлов конфигурации SSH авторизации, созданных BSSS..."
    remove_bsss_files "$SSH_CONFIG_DIR" "disable-pass-auth"
    apply_ssh_auth_settings
}

# Основная функция модуля
ssh_auth() {
    local mode="${1:-normal}"
    
    case "$mode" in
        --check)
            check_password_auth
            ;;
        --default)
            restore_ssh_auth_default
            ;;
        *)
            # Проверка текущего состояния
            local current_state
            current_state=$(check_password_auth)
            
            if [[ "$current_state" != "notfound" ]]; then
                local current_value="${current_state%:*}"
                
                if [[ "$current_value" == "no" ]]; then
                    echo "Авторизация по паролю уже отключена"
                else
                    echo "Текущее состояние авторизации по паролю: включена"
                    if confirm_yes_no "Хотите отключить авторизацию по паролю?"; then
                        # Удаление старых файлов bsss
                        remove_bsss_files "$SSH_CONFIG_DIR" "disable-pass-auth"
                        
                        # Определение индекса для нового файла
                        local index
                        index=$(generate_config_index "${current_state#*:}")
                        
                        # Создание директории если не существует
                        if [[ ! -d "$SSH_CONFIG_DIR" ]]; then
                            mkdir -p "$SSH_CONFIG_DIR"
                        fi
                        
                        # Создание нового файла конфигурации
                        create_ssh_auth_config "$index"
                        
                        log_state_change "Авторизация по паролю" "включена" "отключена"
                        apply_ssh_auth_settings
                    fi
                fi
            else
                echo "Текущее состояние авторизации по паролю: включена (настроек не найдено)"
                if confirm_yes_no "Хотите отключить авторизацию по паролю?"; then
                    # Создание директории если не существует
                    if [[ ! -d "$SSH_CONFIG_DIR" ]]; then
                        mkdir -p "$SSH_CONFIG_DIR"
                    fi
                    
                    # Создание файла конфигурации
                    create_ssh_auth_config "10"
                    
                    log_state_change "Авторизация по паролю" "включена" "отключена"
                    apply_ssh_auth_settings
                fi
            fi
            ;;
    esac
}