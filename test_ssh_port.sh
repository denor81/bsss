#!/usr/bin/env bash

# Исходные данные
SSH_PORT_DEFAULT="22"
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
SSH_MAIN_CONFIG="/etc/ssh/sshd_config"

# Подключение модуля конфигурации
source /root/projects/bsss/modules/helpers/config.sh

# Проверка функции
echo "Testing find_last_active_parameter:"
find_last_active_parameter "Port" "$SSH_MAIN_CONFIG" "$SSH_CONFIG_DIR"