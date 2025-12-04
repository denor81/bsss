#!/usr/bin/env bash
# module-01.sh
# Первый модуль системы
# Возвращает код успеха 0

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
readonly SCRIPT_NAME=$(basename "$0") 

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${MAIN_DIR_PATH}"/../lib/logging.sh

log_info "Модуль: ${MAIN_DIR_PATH}/${SCRIPT_NAME}"

# Модуль успешно завершен
exit 0