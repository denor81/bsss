#!/usr/bin/env bash
# module-01.sh
# Первый модуль системы
# Возвращает код успеха 0

set -Eeuo pipefail

# Коды возврата
readonly SUCCESS=0
readonly ERR_SYS_REBOOT_REQUIRED=1

# Константы
readonly REBOOT_REQUIRED_FILE="/var/run/reboot-required"

# shellcheck disable=SC2155
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
# shellcheck disable=SC2155
readonly SCRIPT_NAME=$(basename "$0")

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${MAIN_DIR_PATH}"/../lib/logging.sh

log_info "Модуль: ${MAIN_DIR_PATH}/${SCRIPT_NAME}"
log_info "Проверка необходимости перезагрузки системы $REBOOT_REQUIRED_FILE"

# Проверяем необходимость перезагрузки системы
if [[ -f "$REBOOT_REQUIRED_FILE" ]]; then
    log_error "Требуется перезагрузки системы. Перезагрузитесь командой reboot. Обнаружен файл $REBOOT_REQUIRED_FILE"
    exit "$ERR_SYS_REBOOT_REQUIRED"
else
    log_info "Перезагрузка не требуется"
fi

# Модуль успешно завершен
exit "$SUCCESS"