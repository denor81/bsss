#!/usr/bin/env bash
# user_confirmation.sh
# Выбор полльзователем параметра
# Использование: source "/lib/user_confirmation.sh"

# @type:        Interactive
# @description: Циклический опрос пользователя до получения валидного значения.
# @params:      Использует ssh::get_ports_from_ss.
#   question        Вопрос на ккоторый нужно получить ответ
#   default         Значения по умолчанию - например "y" - "int"/"str"
#   pattern         regex паттерн ожидаемого ввода - например "[yn]" - "str"
#   hint            Подсказка каие значения ожидаются - например "Y/n" -"str"
#   cancel_keyword  [optional] Ключевое слово для отмены ввода - например "cancel" - "str"
# @stdin:       Ожидает ввод пользователя (TTY).
# @stdout:      Единственная строка с валидированным значением (без \n).
# @stderr:      Текст вопроса (через read -p) и сообщения об ошибках.
# @exit_code:   0 — успешно получено значение
#               2 — отменено пользователем.
io::ask_value() {
    local question=$1 default=$2 pattern=$3 hint=$4 cancel_keyword=${5:-}
    local choice

    while true; do
        read -p "$QUESTION_PREFIX $question [$hint]: " -r choice </dev/tty
        choice=${choice:-$default}

        # Возвращаем код 2 при отмене
        [[ -n "$cancel_keyword" && "$choice" == "$cancel_keyword" ]] && return 2

        if [[ "$choice" =~ ^$pattern$ ]]; then
            printf '%s\0' "$choice"
            break
        fi
        log_error "Ошибка ввода. Ожидается: $hint"
    done
}

# @type:        Validator
# @description: Ждет подтверждение действия. Доступны только y или n
# @params:      Использует ssh::get_ports_from_ss.
#   question    [optional]
#   default     [optional] Значения по умолчанию - например y
# @stdin:       Ожидает ввод пользователя (TTY).
# @stdout:      Ничего.
# @exit_code:   0 — успешно
#               2 — отменено пользователем.
io::confirm_action() {
    local question=${1:-"Продолжить?"}
    
    # Ждем [yn]
    local choice
    choice=$(io::ask_value "$question" "y" "[yn]" "Y/n" | tr -d '\0') || return

    if [[ "$choice" == "n" ]]; then
        return 2
    fi
}