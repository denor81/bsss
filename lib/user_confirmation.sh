#!/usr/bin/env bash
# user_confirmation.sh
# Выбор полльзователем параметра
# Использование: source "/lib/user_confirmation.sh"

_ask_user_confirmation() {
    local question=$1
    local default=$2
    local pattern=$3
    local hint=$4

    while true; do
        read -p "$QUESTION_PREFIX $question [$hint]: " -r choice

        choice=${choice:-$default}
        
        if [[ "${choice,,}" =~ ^$pattern$ ]]; then
            echo "$choice"
            break
        fi
        
        log_error "Некорректный выбор. Доступные символы по паттерну [$pattern]"
    done
}

