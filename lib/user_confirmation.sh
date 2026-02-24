# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Interactive
# @description: Циклический опрос пользователя до получения валидного значения.
# @params:
#   question        str     Вопрос на который нужно получить ответ
#   default         str     [optional] Значения по умолчанию - y n 0
#   allowed_pattern regex   паттерн ожидаемого ввода - ^[yn]$ ^(yes|no)$ ^connected$
#   hint            str     Подсказка какие значения ожидаются - Y/n connected/cancel y/i/0
#   cancel_pattern  regex   [optional] Ключевое слово для отмены ввода - ^cancel$ ^[nc0]$ ^(no|cancel|0)$
# @stdin:       Ожидает ввод пользователя (TTY).
# @stdout:      string/0 Возвращает значение
# @exit_code:   0 — успешно получено значение
#               2 — отменено пользователем.
io::ask_value() {
    local question="$1" default="$2" allowed_pattern="$3" hint="$4" cancel_pattern="${5:-}"
    local choice

    while true; do
        log_question "$question [$hint]"
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] $question [$hint]: " -r choice 2>&3 </dev/tty
        choice=${choice:-$default}
        log_answer "$choice"

        # Возвращаем код 2 при отмене
        [[ -n "$cancel_pattern" && "$choice" =~ $cancel_pattern ]] && return 2

        if [[ "$choice" =~ $allowed_pattern ]]; then
            printf '%s\0' "$choice"
            break
        fi
        log_error "$(_ "common.error_invalid_input" "[$hint]")"
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
    local question=${1:-"$(_ "io.confirm_action.default_question")"}
    
    # при выборе n io::ask_value вернет код 2
    io::ask_value "$question" "y" "^[yn0]$" "Y/n" "^[n0]$" >/dev/null
}
