#!/usr/bin/env bash
# user_confirmation.sh
# Выбор полльзователем параметра
# Использование: source "/lib/user_confirmation.sh"

# @type:        Interactive
# @description: Циклический опрос пользователя до получения валидного значения.
# @params:      Использует get_ssh_ports.
#   question    Вопрос на ккоторый нужно получить ответ
#   default     Значения по умолчанию - например "y" - "int"/"str"
#   pattern     regex паттерн ожидаемого ввода - например "[yn]" - "str"
#   hint        Подсказка каие значения ожидаются - например "Y/n" -"str"
# @stdin:       Ожидает ввод пользователя (TTY).
# @stdout:      Единственная строка с валидированным значением (без \n).
# @stderr:      Текст вопроса (через read -p) и сообщения об ошибках.
# @exit_code:   0 — успешно получено значение.
ask_value() {
    local question=$1 default=$2 pattern=$3 hint=$4
    local choice

    while true; do
        read -p "$QUESTION_PREFIX $question [$hint]: " -r choice
        choice=${choice:-$default}
        
        if [[ "$choice" =~ ^$pattern$ ]]; then
            printf '%s\n' "$choice"
            break
        fi
        log_error "Ошибка ввода. Ожидается: $hint"
    done
}

# @type:        Validator
# @description: Ждет подтверждение действия. Доступны только y или n
# @params:      Использует get_ssh_ports.
#   question    [optional]
#   exit_msg    [optional]
#   default     [optional] Значения по умолчанию - например y
# @stdin:       Ожидает ввод пользователя (TTY).
# @stdout:      Ничего.
# @stderr:      Диагностические сообщения (log_info).
# @exit_code:   0 — успешно, 2 — отменено пользователем.
confirm_action() {
    local question=${1:-"Продолжить?"}
    local exit_msg=${2:-"Выход по запросу пользователя"}
    
    # Ждем [yn]
    local choice
    choice=$(ask_value "$question" "y" "[yn]" "Y/n")

    if [[ "$choice" == "n" ]]; then
        log_info "$exit_msg"
        return 2
    fi
}