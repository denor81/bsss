#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Проверяет SSH порт

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"

# @type:        Orchestrator
# @description: Проверяет состояние SSH портов и правил
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка при проверке портов
check() {
    common::log::current_config "^port"
    ssh::log::active_ports_from_ss "1"
    ssh::log::bsss_configs
    ssh::log::other_configs
}

# @type:        Orchestrator
# @description: Точка входа модуля проверки SSH порта
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - проверка прошла успешно
#               $? - ошибка проверки
main() {
    i18n::load
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
