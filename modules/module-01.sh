#!/usr/bin/env bash
# module-01.sh
# Первый модуль системы
# Возвращает код успеха 0

set -Eeuo pipefail

readonly SYMBOL_SUCCESS="[V]"
readonly SYMBOL_QUESTION="[?]"
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[X]"

log_success() { echo "$SYMBOL_SUCCESS $1"; }
log_error() { echo "$SYMBOL_ERROR $1" >&2; }
log_info() { echo "$SYMBOL_INFO $1"; }

log_info "Модуль: $(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"

# Модуль успешно завершен
exit 0