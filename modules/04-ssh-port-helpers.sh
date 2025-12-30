#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"


# @type:        Source
# @description: Получает список путей через нулевой разделитель.
# @params:
#   dir         [optional] Directory to search in (default: current directory).
#   mask        [optional] Glob pattern (default: "*").
# @stdin:       Ничего.
# @stdout:      NUL-separated strings "path"
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
get_paths_by_mask() {
    local dir=${1:-.}
    local mask=${2:-*}

    ( shopt -s nullglob; printf '%s\0' "${dir%/}"/$mask )
}

# @type:        Filter
# @description: Возвращает строку - путь с типом.
# @params:      нет.
# @stdin:       NUL-separated paths
# @stdout:      NUL-separated strings "path:type"
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
get_modules_types () {
    xargs -r0 awk -F ':[[:space:]]' '
        BEGIN { IGNORECASE=1; ORS="\0" }
        /^# MODULE_TYPE:/ {
            print FILENAME ":" $2
            nextfile  
        }
    '
}

# @type:        Filter
# @description: Возвращает отфильтрованные по типу пути к модулям.
# @params:      
#   type        Module type.
# @stdin:       NUL-separated strings "path:type"
# @stdout:      NUL-separated strings "path"
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
get_modules_by_type () {
    local type=$1

    xargs -r0 awk -v type="$type" -F ':' '
        BEGIN { IGNORECASE=1; ORS="\0" }
        {
            if (type == $2) {
                print FILENAME
            }
        }
    '
}

# @type:        Source
# @description: Получает активные SSH порты из ss.
# @params:      Нет.
# @stdin:       Нет.
# @stdout:      NUL-separated strings "port"
# @stderr:      Ничего.
# @exit_code:   0 — всегда.
get_ssh_ports() {
    ss -Hltnp | awk '
        /"sshd"/ {
            match($4, /:[0-9]+$/, m);
            port = substr(m[0], 2)
            print port
        }
    ' | sort -nu | tr '\n' '\0'
}

# @type:        Validator
# @description: Проверяет возможность определения активных портов.
# @params:      Использует get_ssh_ports.
#   strict_mode [optional] If 1 - return 1 (default 0).
# @stdin:       Не используется.
# @stdout:      Ничего.
# @stderr:      Диагностические сообщения (log_info, log_error).
# @exit_code:   0 — порты определены, 1 — порты не определены (выполнение не возможно).
validate_ssh_ports() {
    local strict_mode=${1:-0}

    local active_ports=""
    active_ports=$(get_ssh_ports | tr '\0' ',')

    if [[ -z "$active_ports" ]]; then
        log_error "Активные порты не определены [ss -ltnp]"
        (( strict_mode == 1 )) && return 1
    else
        log_info "Активные SSH порты [ss -ltnp]: ${active_ports}"
    fi

}



# _delete_paths() {
#     local raw_paths="$1"
#     local path
#     local -a paths=()

#     mapfile -t paths < <(printf '%s' "$raw_paths")

#     for path in "${paths[@]}"; do
#         if rm -rf "$path"; then
#             log_info "Удалено: $path"
#         fi
#     done
# }

# Получение активных портов SSH из ss
# Вернет: 22,888 or none
# _get_active_ssh_ports() {
#     local active_ssh_ports=""
#     local -a ports=() # Объявляем заранее

#     active_ssh_ports=$(ss -Htlnp | awk '
#         /users:.*"sshd"/ {
#             if (match($4, /:[0-9]+$/)) {
#                 print substr($4, RSTART + 1)
#             }
#         }' | sort -u) || return 1

#     # Важно: наполняем только если не пусто, чтобы не было "пустого элемента"
#     if [[ -n "$active_ssh_ports" ]]; then
#         mapfile -t ports < <(printf '%s' "$active_ssh_ports")
#     fi

#     if (( ${#ports[@]} == 0 )); then
#         log_error "Не найдены активные порты SSH [ss -nlptu], работа модуля не может быть продолжена"
#         return 1
#     fi
    
#     (local IFS=","; echo "${ports[*]}")
# }

# Получаю все конфиг файлы содержащие Port
# Вернет: {path_to_file}\t{port}\n or none
# _get_paths_and_port() {
#     local additional_path="${1:-}"
#     local mask="$2"

#     local raw_paths=""
#     local -a available_paths=()

#     raw_paths=$(_get_paths_by_mask "${SSH_CONFIGD_DIR}" "$mask") || return 1

#     if [[ -n "$raw_paths" ]]; then
#         mapfile -t available_paths < <(printf '%s' "$raw_paths")
#     fi

#     if (( ${#available_paths[@]} > 0 )); then
#         [[ -f "$additional_path" ]] && available_paths+=("$additional_path")
        
#         # awk выполнится успешно, даже если в файлах нет слова Port (вернет пустую строку)
#         awk 'BEGIN { OFS="\t"; IGNORECASE=1 } /^[[:space:]]*Port[[:space:]]+/ { print FILENAME, $2 }' "${available_paths[@]}"
#     fi
# }

# check_active_ports() {
#     local active_ports=""

#     # Ожидаем получение активных портов, если портов нет, то это значит, что не можем получить данные из ss -nlptu и продолжение не возможно
#     active_ports=$(_get_active_ssh_ports) || return 1 # Пишем в переменну, что бы в случае > 0 остановить скрипт
#     log_info "Активные SSH порты [ss -nlptu]: ${active_ports}"
# }

# Ищем все порты в файлах конфигурации /etc/ssh...
# Возврат:
# [ ] [04-ssh-port-check.sh] Активные SSH правила: 40
# [ ] ---- /etc/ssh/sshd_config.d/40-bsss-ssh-port.conf 40

# check_config_ports() {
#     local additional_path="${1:-}"
#     local mask="$2"
#     local mask_name="$3"

#     local raw_paths=""
#     local ports_list
#     local -a paths_with_ports=()
#     local path_w_port

#     # ожидаем получить список портов из каталога настроек SSH, если пусто, то портов нет, но скрипт может быть продолжен
#     raw_paths=$(_get_paths_and_port "$additional_path" "$mask") || return 1
#     mapfile -t paths_with_ports < <(printf '%s' "${raw_paths//$'\t'/ }") # Заменяю \t на пробел

#     if (( "${#paths_with_ports[@]}" > 0 )); then

#         # Берем только порты поссле \t в каждой строке
#         ports_list=$(echo "$raw_paths" | cut -f2 | sort -u | paste -sd, -)

#         log_info "Активные ${mask_name^^} правила: $ports_list"

#         for path_w_port in "${paths_with_ports[@]}"; do
#             log_info_simple_tab "$path_w_port"
#         done
#     else
#         log_info "Нет активных правил ${mask_name^^} портов"
#     fi
# }
