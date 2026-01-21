#!/usr/bin/env bash
# user_confirmation.sh
# Выбор полльзователем параметра
# Использование: source "/lib/user_confirmation.sh"

# @type:        Source
# @description: Ask user for value input, or return default in test mode
# @params:      Использует ssh::get_ports_from_ss.
#   question        Вопрос на который нужно получить ответ
#   default         Значения по умолчанию - например "y" - "int"/"str"
#   pattern         regex паттерн ожидаемого ввода - например "[yn]" - "str"
#   hint            Подсказка какие значения ожидаются - например "Y/n" -"str"
#   cancel_keyword  [optional] Ключевое слово для отмены ввода - например "cancel" - "str"
# @stdin:       none
# @stdout:      value\0 (NUL-terminated)
# @stderr:      Текст вопроса (через read -p) и сообщения об ошибках.
# @exit_code:   0 - success
#               2 - user cancelled (cancel_keyword matched)
io::ask_value() {
    local question=$1 default=$2 pattern=$3 hint=$4 cancel_keyword=${5:-}
    local choice

    # Test mode: return predefined value
    if [[ "$TEST_MODE" == "true" ]]; then
        # Check if this specific prompt should fail (for testing error paths)
        if [[ -n "${TEST_FAIL_CONFIRMATION:-}" ]] && [[ "$question" == *"$TEST_FAIL_CONFIRMATION"* ]]; then
            # Return 2 for cancellation (BSSS standard per AGENTS.md)
            # CRITICAL: Do NOT output anything when returning code 2
            return 2
        fi
        # FIX: Handle empty default value in TEST_MODE
        # Return "1" (first valid option) if default is empty
        # Otherwise return the default value
        if [[ -z "$default" ]]; then
            printf '%s\0' "1"
        else
            printf '%s\0' "$default"
        fi
        return 0
    fi

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

# @type:        Orchestrator
# @description: Ask user for Y/n confirmation, or return predefined value in test mode
# @params:
#   question    [optional] Question to ask user
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - user confirmed (or test mode success)
#               2 - user cancelled (or test mode cancellation)
io::confirm_action() {
    local question=${1:-"Продолжить?"}
    
    # Test mode: return success by default
    if [[ "$TEST_MODE" == "true" ]]; then
        # Check if this specific prompt should fail (for testing error paths)
        if [[ -n "${TEST_FAIL_CONFIRMATION:-}" ]] && [[ "$question" == *"$TEST_FAIL_CONFIRMATION"* ]]; then
            # Return 2 for cancellation (BSSS standard per AGENTS.md)
            return 2
        fi
        return 0
    fi
    
    local choice
    # при выборе n возвращаем 2
    choice=$(io::ask_value "$question" "y" "[yn]" "Y/n" "n"| tr -d '\0') || return

    [[ "$choice" == "y" || "$choice" == "Y" ]] && return 0 || return 2
}