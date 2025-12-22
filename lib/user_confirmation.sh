#!/usr/bin/env bash
# user_confirmation.sh
# Выбор полльзователем параметра
# Использование: source "/lib/user_confirmation.sh"

_ask_value() {
    local question=$1 default=$2 pattern=$3 hint=$4
    local choice

    while true; do
        read -p "$QUESTION_PREFIX $question [$hint]: " -r choice
        choice=${choice:-$default}
        
        if [[ "${choice,,}" =~ ^$pattern$ ]]; then
            echo "${choice,,}"
            break
        fi
        log_error "Ошибка ввода. Ожидается: $hint"
    done
}

_confirm_action() {
    local question=${1:-"Продолжить?"}
    local exit_msg=${2:-"Выход по запросу пользователя"}
    local default=${3:-"y"}
    
    # Ждем [yn]
    local choice
    choice=$(_ask_value "$question" "$default" "[yn]" "${default}/n")

    if [[ "$choice" == "n" ]]; then
        log_info "$exit_msg"
        return 2
    fi
}