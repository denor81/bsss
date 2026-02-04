#!/usr/bin/env bash
#
# @type:        Source
# @description: Переводчик сообщений по ключу
# @params:      message_key - Ключ сообщения в i18n системе
#               args - Аргументы для форматирования (опционально)
# @stdin:       нет
# @stdout:      Переведенное сообщение
# @exit_code:   0 - успех, 1 - ключ не найден

declare -gA I18N_MESSAGES

_() {
    local key="$1"
    shift
    
    if [[ -v I18N_MESSAGES["$key"] ]]; then
        if [[ $# -gt 0 ]]; then
            printf "${I18N_MESSAGES["$key"]}" "$@"
        else
            echo "${I18N_MESSAGES["$key"]}"
        fi
    else
        echo "[$key] NOT TRANSLATED" >&2
    fi
}

# @type:        Source
# @description: Псевдоним для функции _() для использования в модулях
# @params:      message_key - Ключ сообщения в i18n системе
#               args - Аргументы для форматирования (опционально)
# @stdin:       нет
# @stdout:      Переведенное сообщение
# @exit_code:   0 - успех, 1 - ключ не найден
i18n::get() {
    _ "$@"
}
