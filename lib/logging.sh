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
readonly SYMBOL_ACTUAL_INFO="[i]"
readonly SYMBOL_ERROR="[x]"

readonly QUESTION_PREFIX="$SYMBOL_QUESTION [$CURRENT_MODULE_NAME]"

# @type:        Sink
# @description: Новая строка
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
log::new_line() {
    echo >&2
}

# @type:        Sink
# @description: Выводит успешное сообщение с символом [v]
# @params:      message - Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_success() {
    echo -e "$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $1" >&2
}

# @type:        Sink
# @description: Выводит сообщение об ошибке с символом [x]
# @params:      message - Сообщение об ошибке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_error() {
    echo -e "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $1" >&2
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info() {
    echo -e "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $1" >&2
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Приоритетное информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_bold_info() {
    local color='\e[1m'
    local color_reset='\e[0m'
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_INFO" "$CURRENT_MODULE_NAME" "$1" >&2
}

# @type:        Sink
# @description: Выводит предупреждение с символом [!]
# @params:      message - Предупреждающее сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_warn() {
    echo -e "$SYMBOL_WARN [$CURRENT_MODULE_NAME] $1" >&2
}

# @type:        Sink
# @description: Выводит важное сообщение с символом [A]
# @params:      message - Важное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_attention() {
    local color='\e[41;37m'
    local color_reset='\e[0m'
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_ATTENTION" "$CURRENT_MODULE_NAME" "$1" >&2
}

# @type:        Sink
# @description: Выводит важное сообщение с символом [i]
# @params:      message - актуальная информация
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_actual_info() {
    local color='\e[37;42m'
    local color_reset='\e[0m'
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_ACTUAL_INFO" "$CURRENT_MODULE_NAME" "$1" >&2
}

# @type:        Sink
# @description: Выводит информационное сообщение с отступом
# @params:      message - Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info_simple_tab() {
    echo -e "$SYMBOL_INFO    $1" >&2
}

# @type:        Sink
# @description: Выводит информационное сообщение о запуске процесса
# @params:      module_name - Имя модуля (опционально, по умолчанию $CURRENT_MODULE_NAME)
#               pid - PID процесса (опционально, по умолчанию $$)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_start() {
    echo -e "$SYMBOL_INFO [${1:-$CURRENT_MODULE_NAME}]>>start>>[PID: ${2:-$$}]" >&2
}

# @type:        Sink
# @description: Выводит информационное сообщение о остановке процесса
# @params:      module_name - Имя модуля (опционально, по умолчанию $CURRENT_MODULE_NAME)
#               pid - PID процесса (опционально, по умолчанию $$)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_stop() {
    echo >&2
    echo -e "$SYMBOL_INFO [${1:-$CURRENT_MODULE_NAME}]>>stop>>[PID: ${2:-$$}]" >&2
}

# @type:        Sink
# @description: Выводит разделитель из 80 символов '#'
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
log::draw_border() {
    printf '%.0s#' {1..80} >&2; echo >&2
}

# @type:        Sink
# @description: Выводит разделитель из 80 символов '-'
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
log::draw_lite_border() {
    # printf '%.0s-' {1..80} >&2; echo >&2
    log::new_line >&2
}
