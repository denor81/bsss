#!/usr/bin/env bash
# module-01.sh
# Первый модуль системы
# Возвращает код успеха 0

set -Eeuo pipefail

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

log_info "Модуль: $(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"

# Модуль успешно завершен
exit 0