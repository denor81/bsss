#!/usr/bin/env bash
# module-01.sh
# Тестовый
# Возвращает код успеха 0

set -Eeuo pipefail

# shellcheck disable=SC2155
readonly THIS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
# Получаем только имя файла из переменной $0
# shellcheck disable=SC2155
readonly SCRIPT_NAME=$(basename "$0")
# shellcheck disable=SC2034
readonly CURRENT_MODULE_NAME="$SCRIPT_NAME"

CHECK_FLAG=0

# Коды возврата
readonly SUCCESS=0
readonly ERR_RUN_FLAG=1

# Подключаем библиотеку функций логирования
# shellcheck disable=SC1091
source "${THIS_DIR_PATH}"/../lib/logging.sh

log_info "Модуль: ${THIS_DIR_PATH}/${SCRIPT_NAME}"

# Запуск без параметров
if [ "$#" -eq 0 ]; then
    RUN=1
fi

# Проверяем необходимость перезагрузки системы
if [[ "$CHECK_FLAG" -eq 1 ]]; then
    log_info "ЗАПУСК МОДУЛЯ $SCRIPT_NAME В РЕЖИМЕ ПРОВЕРКИ"
elif [[ "$RUN" -eq 1 ]]; then
    log_info "ЗАПУСК МОДУЛЯ $SCRIPT_NAME В СТАНДАРТНОМ РЕЖИМЕ"
else
    log_error "Не определен флаг запуска"
    exit "$ERR_RUN_FLAG"
fi

# Модуль успешно завершен
exit "$SUCCESS"
