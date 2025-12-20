#!/usr/bin/env bash
# MODULE_TYPE: helper

set -Eeuo pipefail

# Получение активных портов SSH
_get_active_ssh_ports() {
    local active_ssh_ports=""
    local -a ports=() # Объявляем заранее

    active_ssh_ports=$(ss -Htlnp | awk '
        /users:.*"sshd"/ {
            if (match($4, /:[0-9]+$/)) {
                print substr($4, RSTART + 1)
            }
        }' | sort -u) || return 1

    # Важно: наполняем только если не пусто, чтобы не было "пустого элемента"
    if [[ -n "$active_ssh_ports" ]]; then
        mapfile -t ports < <(printf '%s' "$active_ssh_ports")
    fi

    if (( ${#ports[@]} == 0 )); then
        log_error "Не найдены активные порты SSH [ss -nlptu], работа модуля не может быть продолжена"
        return 1
    fi
    
    (local IFS=","; echo "${ports[*]}")
}

# Получаю все конфиг файлы содержащие Port
# Возвращает список файлов и портов: "FILENAME\tPORT" или пусто
_get_all_files_by_mask_with_port() {
    local additional_path="${1:-}"
    local mask="$2"
    local raw_paths=""
    local -a available_paths=()

    raw_paths=$(_get_files_paths_by_mask "${SSH_CONFIGD_DIR}" "$mask") || return 1

    if [[ -n "$raw_paths" ]]; then
        mapfile -t available_paths < <(printf '%s' "$raw_paths")
    fi

    if (( ${#available_paths[@]} > 0 )); then
        [[ -f "$additional_path" ]] && available_paths+=("$additional_path")
        
        # awk выполнится успешно, даже если в файлах нет слова Port (вернет пустую строку)
        awk 'BEGIN { OFS="\t"; IGNORECASE=1 } /^[[:space:]]*Port[[:space:]]+/ { print FILENAME, $2 }' "${available_paths[@]}"
    fi
}

# Получаю все конфиг порты
_get_all_config_ports_by_mask() {
    local additional_path="${1:-}"
    local mask="$2"
    local raw_data=""
    local -a ports=()

    # Пробрасываем ошибку, если вложенная функция вернула 1
    raw_data=$(_get_all_files_by_mask_with_port "$additional_path" "$mask") || return 1

    if [[ -n "$raw_data" ]]; then
        local ports_list=""
        # Пробрасываем ошибку всей цепочки команд
        ports_list=$(printf '%s\n' "$raw_data" | awk '{ print $2 }' | sort -u) || return 1
        
        mapfile -t ports < <(printf '%s' "$ports_list")
    fi

    if (( ${#ports[@]} > 0 )); then
        (local IFS=","; echo "${ports[*]}")
    fi
}
