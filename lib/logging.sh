#!/usr/bin/env bash
# logging.sh
# Библиотека функций для унифицированного логирования
# Использование: source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

# Символы для обозначения статуса сообщений
readonly SYMBOL_SUCCESS="[V]"
readonly SYMBOL_QUESTION="[?]" # Используется в read (read -p "$SYMBOL_QUESTION Ваш выбор (Y/n/c): " -r)
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[X]"

# Функции логирования
# Выводит успешное сообщение с символом [V]
log_success() { 
    echo "$SYMBOL_SUCCESS $1"
}

# Выводит сообщение об ошибке с символом [X] в stderr
log_error() { 
    echo "$SYMBOL_ERROR $1" >&2
}

# Выводит информационное сообщение с символом [ ]
log_info() { 
    echo "$SYMBOL_INFO $1"
}