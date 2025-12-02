#!/usr/bin/env bash
# module-01.sh
# Первый модуль системы
# Возвращает код успеха 0

set -Eeuo pipefail

log_success() { echo -e "[v] $1"; }
log_error() { echo -e "[x] $1" >&2; }
log_info() { echo -e "[ ] $1"; }

log_info "Модуль: $(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"

# Модуль успешно завершен
exit 0