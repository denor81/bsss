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

# ============================================================================
# FILE LOGGING SUPPORT
# ============================================================================

# @type:        Sink
# @description: Writes message to log file if LOG_FILE is set
# @params:      message - Message to write
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log::to_file() {
    local message="$1"
    
    # Only write to file if LOG_FILE is set and writable
    if [[ -n "${LOG_FILE:-}" ]]; then
        # Ensure log directory exists
        local log_dir
        log_dir="$(dirname "$LOG_FILE")"
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" 2>/dev/null || true
        fi
        
        # Write to file using printf (safer than echo for special characters)
        # Note: Concurrent writes may interleave - this is acceptable for test logs
        printf '%s\n' "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# @type:        Sink
# @description: Generates structured log entry with timestamp
# @params:      level - Log level (INFO, WARN, ERROR, etc.)
#               module - Module name
#               pid - Process ID
#               message - Log message
# @stdin:       нет
# @stdout:      Structured log string
# @exit_code:   0 - всегда
log::format_entry() {
    local level="$1"
    local module="$2"
    local pid="$3"
    local message="$4"
    
    # ISO 8601 timestamp with milliseconds
    local timestamp
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S.%3NZ')"
    
    # Structured format: TIMESTAMP|LEVEL|MODULE|PID|MESSAGE
    # CRITICAL: Must include \n at end for proper log file parsing
    printf '%s|%s|%s|%s|%s\n' "$timestamp" "$level" "$module" "$pid" "$message"
}

readonly QUESTION_PREFIX="$SYMBOL_QUESTION [$CURRENT_MODULE_NAME]"

# @type:        Sink
# @description: Выводит успешное сообщение с символом [v]
# @params:      message - Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_success() {
    local message="$1"
    local terminal_message="$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $message"
    
    # Terminal output (existing behavior)
    echo -e "$terminal_message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "SUCCESS" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
}

# @type:        Sink
# @description: Выводит сообщение об ошибке с символом [x]
# @params:      message - Сообщение об ошибке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_error() {
    local message="$1"
    local terminal_message="$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $message"
    
    # Terminal output (existing behavior)
    echo -e "$terminal_message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "ERROR" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info() {
    local message="$1"
    local terminal_message="$SYMBOL_INFO [$CURRENT_MODULE_NAME] $message"
    
    # Terminal output (existing behavior)
    echo -e "$terminal_message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Приоритетное информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_bold_info() {
    local message="$1"
    local color='\e[1m'
    local color_reset='\e[0m'
    
    # Terminal output (existing behavior)
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_INFO" "$CURRENT_MODULE_NAME" "$message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
}

# @type:        Sink
# @description: Выводит предупреждение с символом [!]
# @params:      message - Предупреждающее сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_warn() {
    local message="$1"
    local terminal_message="$SYMBOL_WARN [$CURRENT_MODULE_NAME] $message"
    
    # Terminal output (existing behavior)
    echo -e "$terminal_message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "WARN" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
}

# @type:        Sink
# @description: Выводит важное сообщение с символом [A]
# @params:      message - Важное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_attention() {
    local message="$1"
    local color='\e[41;37m'
    local color_reset='\e[0m'
    
    # Terminal output (existing behavior)
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_ATTENTION" "$CURRENT_MODULE_NAME" "$message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "ATTENTION" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
}

# @type:        Sink
# @description: Выводит важное сообщение с символом [i]
# @params:      message - актуальная информация
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_actual_info() {
    local message="$1"
    local color='\e[37;42m'
    local color_reset='\e[0m'
    
    # Terminal output (existing behavior)
    printf "${color}%s [%s] %s${color_reset}\n" "$SYMBOL_ACTUAL_INFO" "$CURRENT_MODULE_NAME" "$message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
}

# @type:        Sink
# @description: Выводит информационное сообщение с отступом
# @params:      message - Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info_simple_tab() {
    local message="$1"
    local terminal_message="$SYMBOL_INFO    $message"
    
    # Terminal output (existing behavior)
    echo -e "$terminal_message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$CURRENT_MODULE_NAME" "$$" "$message")"
        log::to_file "$structured_message"
    fi
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
    local message="$SYMBOL_INFO [${module_name}]>>start>>[PID: ${pid}]"
    
    # Terminal output (existing behavior)
    echo -e "$message" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$module_name" "$pid" ">>start>>")"
        log::to_file "$structured_message"
    fi
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
    
    # Terminal output (existing behavior)
    echo >&2
    echo -e "$SYMBOL_INFO [${module_name}]>>stop>>[PID: ${pid}]" >&2
    
    # File output (new)
    if [[ "$LOG_MODE" == "file" ]] || [[ "$LOG_MODE" == "both" ]]; then
        local structured_message
        structured_message="$(log::format_entry "INFO" "$module_name" "$pid" ">>stop>>")"
        log::to_file "$structured_message"
    fi
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
    echo >&2
}