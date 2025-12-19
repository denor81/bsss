#!/usr/bin/env bash
# user_confirmation.sh
# Выбор полльзователем параметра
# Использование: source "/lib/user_confirmation.sh"

_ask_user_confirmation() {
    local question=$1
    local default=$2
    local allowed=$3

    while true; do
        read -p "$QUESTION_PREFIX $question [$allowed]: " -r choice
        choice=${choice:-$default}
        
        if [[ ${choice,,} =~ ^[$allowed]$ ]]; then
            echo "${choice,,}"
            break
        fi
        
        log_error "Некорректный выбор. Доступные символы [$allowed]"
    done
}