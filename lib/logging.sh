#!/usr/bin/env bash
# logging.sh
# Библиотека функций для унифицированного логирования
# Использование: source "${THIS_DIR_PATH}/lib/logging.sh"

# Символы для обозначения статуса сообщений
# shellcheck disable=SC2034
readonly SYMBOL_SUCCESS="[v]"
readonly SYMBOL_QUESTION="[?]" # Используется в lib/user_confirmation.sh
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_WARN="[!]"
readonly SYMBOL_ATTENTION="[A]"
readonly SYMBOL_ERROR="[x]"

readonly QUESTION_PREFIX="$SYMBOL_QUESTION [$CURRENT_MODULE_NAME]"

# Функции логирования
# Выводит успешное сообщение с символом [v]
# Все логи отправляем в stderr, что бы сохранять stdout пустым
log_success() {
    echo -e "$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит сообщение об ошибке с символом [x] в stderr
log_error() {
    echo -e "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит информационное сообщение с символом [ ]
log_info() {
    echo -e "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит предупреждение с символом [!]
log_warn() {
    echo -e "$SYMBOL_WARN [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит предупреждение с символом [A]
log_attention() {
    local color_red='\e[41;37m'
    local color_reset='\e[0m'
    printf "${color_red}%s [%s] %s${color_reset}\n" "$SYMBOL_ATTENTION" "$CURRENT_MODULE_NAME" "$1" >&2
}

# Выводит информационное сообщение с символом [ ]
log_info_simple_tab() {
    echo -e "$SYMBOL_INFO    $1" >&2
}

# @type:        UNDEFINED
# @description: Выводит разделитель из 80 символов '#'
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
log::draw_border() {
    printf '%.0s#' {1..80} >&2; echo >&2
}

# @type:        UNDEFINED
# @description: Выводит разделитель из 80 символов '#'
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
log::draw_lite_border() {
    printf '%.0s-' {1..80} >&2; echo >&2
}