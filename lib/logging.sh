readonly SYMBOL_SUCCESS="[v]"
readonly SYMBOL_QUESTION="[?]"
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_DEBUG="[D]"
readonly SYMBOL_WARN="[!]"
readonly SYMBOL_ATTENTION="[A]"
readonly SYMBOL_ACTUAL_INFO="[i]"
readonly SYMBOL_ERROR="[x]"

# Journal mapping: BSSS log type -> systemd journal priority
readonly -A JOURNAL_MAP=(
    [DEBUG]="debug"
    [INFO]="info" [QUESTION]="info" [ANSWER]="info" [BOLD_INFO]="info" [INFO_TAB]="info" [ACTUAL_INFO]="info" [START]="info" [STOP]="info"
    [WARN]="warning"
    [ERROR]="err"
    [ATTENTION]="crit"
    [SUCCESS]="notice"
)

# Check if logger command is available for journal logging
command -v logger >/dev/null 2>&1 && readonly LOG_JOURNAL_ENABLED=1 || readonly LOG_JOURNAL_ENABLED=0

# @type:        Sink
# @description: Sends message to systemd journal if logging is enabled
# @params:      message - Message to log
#               log_type - BSSS log type (SUCCESS, ERROR, INFO, etc.)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log::to_journal() {
    local msg="$1"
    local log_type="$2"
    local priority

    if (( LOG_JOURNAL_ENABLED )); then
        priority="${JOURNAL_MAP[$log_type]:-info}"
        logger --id -t "$UTIL_NAME" -p "user.$priority" "[$CURRENT_MODULE_NAME] $msg" || true
    fi
}


# @type:        Sink
# @description: Выводит пустую строку
# @params:      нет
# @stdin:       нет
# @stdout:      новая строка
# @exit_code:   0 - всегда
new_line() {
    echo >&2
}

# @type:        Sink
# @description: Выводит успешное сообщение с символом [v]
# @params:      message - Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_success() {
    local msg="$1"
    local type="SUCCESS"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит сообщение об ошибке с символом [x]
# @params:      message - Сообщение об ошибке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_error() {
    local msg="$1"
    local type="ERROR"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info() {
    local msg="$1"
    local type="INFO"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
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
    local type="QUESTION"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: ТОЛЬКО в файл - ответ с символом [?]
#               В терминал ответ выводится стандартными средствами read
# @params:      answer
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_answer() {
    local msg="$1"
    local type="ANSWER"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_debug() {
    local msg="$1"
    local type="DEBUG"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_DEBUG [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Приоритетное информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_bold_info() {
    local msg="$1"
    local type="BOLD_INFO"
    local formatted_msg
    local color='\e[1m'
    local color_reset='\e[0m'
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_INFO" "$CURRENT_MODULE_NAME" "$1" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит предупреждение с символом [!]
# @params:      message - Предупреждающее сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_warn() {
    local msg="$1"
    local type="WARN"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_WARN [$CURRENT_MODULE_NAME] $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит важное сообщение с символом [A]
# @params:      message - Важное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_attention() {
    local msg="$1"
    local type="ATTENTION"
    local formatted_msg
    local color='\e[41;37m'
    local color_reset='\e[0m'
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_ATTENTION" "$CURRENT_MODULE_NAME" "$msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит важное сообщение с символом [i]
# @params:      message - актуальная информация
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_actual_info() {
    local msg="${1:-Актуальная информация после внесения изменений}"
    local type="ACTUAL_INFO"
    local formatted_msg
    local color='\e[37;42m'
    local color_reset='\e[0m'
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_ACTUAL_INFO" "$CURRENT_MODULE_NAME" "$msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит информационное сообщение с отступом
# @params:      message - Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info_simple_tab() {
    local msg="$1"
    local type="INFO_TAB"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$CURRENT_MODULE_NAME] $msg"
    echo -e "$SYMBOL_INFO    $msg" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: Выводит информационное сообщение о запуске процесса
# @params:      module_name - Имя модуля (опционально, по умолчанию $CURRENT_MODULE_NAME)
#               pid - PID процесса (опционально, по умолчанию $$)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_start() {
    local module_name="${1:-$CURRENT_MODULE_NAME}"
    local pid="${2:-$$}"
    local type="START"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$module_name] PID: $pid"
    echo -e "$SYMBOL_INFO [$module_name]>>start>>[PID: $pid]" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "PID: $pid" "$type"
}

# @type:        Sink
# @description: Выводит информационное сообщение о остановке процесса
# @params:      module_name - Имя модуля (опционально, по умолчанию $CURRENT_MODULE_NAME)
#               pid - PID процесса (опционально, по умолчанию $$)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_stop() {
    local module_name="${1:-$CURRENT_MODULE_NAME}"
    local pid="${2:-$$}"
    local type="STOP"
    local formatted_msg
    formatted_msg="$(date '+%H:%M:%S') [$type] [$module_name] PID: $pid"
    echo -e "$SYMBOL_INFO [$module_name]>>stop>>[PID: $pid]" >&2
    echo "$formatted_msg" >> "$CURRENT_LOG_SYMLINK" 2>/dev/null || true
    log::to_journal "PID: $pid" "$type"
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
