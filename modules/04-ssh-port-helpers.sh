#!/usr/bin/env bash
# MODULE_TYPE: helper

set -Eeuo pipefail

# Получение активных портов SSH
_get_active_ssh_ports() {
    # -H: без заголовков
    # -t: TCP, -l: LISTEN, -n: цифры вместо имен, -p: показать процессы
    mapfile -t ports < <(ss -Htlnp | awk '
        /users:.*"sshd"/ {
            # Находим двоеточие, за которым следуют только цифры в конце поля
            if (match($4, /:[0-9]+$/)) {
                # Печатаем всё, что после двоеточия (сам порт)
                print substr($4, RSTART + 1)
            }
        }' | sort -u)

    (( ${#ports[@]} == 0 )) && { log_error "Не найдены активные порты SSH [ss -nlptu], работа модуля не может быть продолжена"; return 1; }
    
    (local IFS=","; echo "${ports[*]}")
}

# Получаю все конфиг файлы содержащие Port
_get_all_config_files_with_port() {
    mapfile -t available_paths < <(_get_files_paths_by_mask "${SSH_CONFIGD_DIR}" "$SSH_CONFIG_FILE_MASK")

    [[ -f "$SSH_CONFIG_FILE" ]] && available_paths+=("$SSH_CONFIG_FILE")
    
    mapfile -t files_and_ports < <(awk 'BEGIN { OFS="\t"; IGNORECASE=1 } /^[[:space:]]*Port[[:space:]]+/ { print FILENAME, $2 }' "${available_paths[@]}")

    if (( ${#files_and_ports[@]} > 0 )); then
        printf '%s\n' "${files_and_ports[@]}"
    fi
}

# Получаю все конфиг порты
_get_all_config_ports() {
    mapfile -t available_files_and_ports < <(_get_all_config_files_with_port)

    if (( ${#available_files_and_ports[@]} > 0 )); then
        mapfile -t ports < <(printf '%s\n' "${available_files_and_ports[@]}" | awk '{ print $2 }' | sort -u)
        (local IFS=","; echo "${ports[*]}")
    fi
}