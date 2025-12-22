#!/usr/bin/env bash
# logging.sh
# Библиотека функций для унифицированного логирования
# Использование: source "${THIS_DIR_PATH}/lib/logging.sh"

# Символы для обозначения статуса сообщений
# shellcheck disable=SC2034
readonly SYMBOL_SUCCESS="[V]"
readonly SYMBOL_QUESTION="[?]" # Используется в lib/user_confirmation.sh
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[X]"

readonly QUESTION_PREFIX="$SYMBOL_QUESTION [$CURRENT_MODULE_NAME]"

# Функции логирования
# Выводит успешное сообщение с символом [V]
# Все логи отправляем в stderr, что бы сохранять stdout пустым
log_success() {
    echo -e "$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит сообщение об ошибке с символом [X] в stderr
log_error() {
    echo -e "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит информационное сообщение с символом [ ]
log_info() {
    local symbol=${2:-$SYMBOL_INFO}
    echo -e "$symbol [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит информационное сообщение с символом [ ]
log_info_simple_tab() {
    echo -e "$SYMBOL_INFO ---- $1" >&2
}