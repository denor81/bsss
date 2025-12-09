#!/usr/bin/env bash
# logging.sh
# Библиотека функций для унифицированного логирования
# Использование: source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

# Символы для обозначения статуса сообщений
# shellcheck disable=SC2034
readonly SYMBOL_SUCCESS="[V]"
readonly SYMBOL_QUESTION="[?]" # Используется в read (read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] Ваш выбор (Y/n/c): " -r)
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[X]"

# Функции логирования
# Выводит успешное сообщение с символом [V]
# Все логи отправляем в stderr, что бы сохранять stdout пустым
log_success() {
    echo "$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит сообщение об ошибке с символом [X] в stderr
log_error() {
    echo "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $1" >&2
}

# Выводит информационное сообщение с символом [ ]
log_info() {
    echo "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $1" >&2
}