# @type:        Interactive
# @description: Циклический опрос пользователя до получения валидного значения.
# @params:
#   question        Вопрос на который нужно получить ответ
#   default         Значения по умолчанию - например "y" - "int"/"str"
#   pattern         regex паттерн ожидаемого ввода - например "[yn]" - "str"
#   hint            Подсказка какие значения ожидаются - например "Y/n" -"str"
#   cancel_keyword  [optional] Ключевое слово для отмены ввода - например "cancel" - "str"
# @stdin:       Ожидает ввод пользователя (TTY).
# @stdout:      string/0
# @stderr:      Текст вопроса (через read -p) и сообщения об ошибках.
# @exit_code:   0 — успешно получено значение
#               2 — отменено пользователем.
io::ask_value() {
    local question=$1 default=$2 pattern=$3 hint=$4 cancel_keyword=${5:-}
    local choice

    while true; do
        log_question "$question [$hint]"
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] $question [$hint]: " -r choice </dev/tty
        choice=${choice:-$default}
        log_answer "$choice"

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
    
    # при выборе n io::ask_value вернет код 2
    io::ask_value "$question" "y" "[yn]" "Y/n" "n" >/dev/null
}
