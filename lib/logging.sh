# Символы для обозначения статуса сообщений
# shellcheck disable=SC2034
readonly SYMBOL_SUCCESS="[v]"
readonly SYMBOL_QUESTION="[?]" # Используется в lib/user_confirmation.sh
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_DEBUG="[D]"
readonly SYMBOL_WARN="[!]"
readonly SYMBOL_ATTENTION="[A]"
readonly SYMBOL_ACTUAL_INFO="[i]"
readonly SYMBOL_ERROR="[x]"

# @type:        Sink
# @description: Выводит успешное сообщение с символом [v]
# @params:      message - Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_success() {
    local msg="$1"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [SUCCESS] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
}

# @type:        Sink
# @description: Выводит сообщение об ошибке с символом [x]
# @params:      message - Сообщение об ошибке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_error() {
    local msg="$1"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [ERROR] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info() {
    local msg="$1"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [INFO] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
}

# @type:        Sink
# @description: ТОЛЬКО в файл - вопрос с символом [?]
#               В терминал вопрос выводится стандартными средствами read
# @params:      question - вопрос
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_question() {
    local msg="$1"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [QUESTION] [$CURRENT_MODULE_NAME] $msg"
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_debug() {
    local msg="$1"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [DEBUG] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_DEBUG [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Приоритетное информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_bold_info() {
    local msg="$1"
    local formatted_msg
    local color='\e[1m'
    local color_reset='\e[0m'
    formatted_msg="$(date '+%H:%M:%S') [BOLD_INFO] [$CURRENT_MODULE_NAME] $msg"
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_INFO" "$CURRENT_MODULE_NAME" "$1" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
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
    local text="${1:-Актуальная информация после внесения изменений}"
    local color='\e[37;42m'
    local color_reset='\e[0m'
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_ACTUAL_INFO" "$CURRENT_MODULE_NAME" "$text" >&2
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
    # echo >&2
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
