#!/usr/bin/env bash

# Глобальная переменная для режима verbose
declare -g VERBOSE_MODE=false

# Инициализация логирования
init_logging() {
    VERBOSE_MODE="${1:-false}"
}

# Логирование шага
log_step() {
    local message="$1"
    echo "=== $message ==="
}

# Подробное логирование (только в verbose режиме)
log_verbose() {
    local message="$1"
    if [[ "$VERBOSE_MODE" == true ]]; then
        echo "  $message"
    fi
}

# Логирование состояния до/после
log_state_change() {
    local param="$1"
    local old_value="$2"
    local new_value="$3"
    
    echo "  $param: $old_value -> $new_value"
}