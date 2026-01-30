#!/usr/bin/env bash
# Проверяет SSH порт
# MODULE_ORDER: 50
# MODULE_TYPE: check

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ssh-port.sh"

# @type:        Orchestrator
# @description: Проверяет состояние SSH портов и правил
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка при проверке портов
check() {
    ssh::log::active_ports_from_ss "1"
    ssh::log::bsss_configs
    ssh::log::other_configs
}

# @type:        Orchestrator
# @description: Точка входа модуля проверки SSH порта
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - проверка прошла успешно
#               $? - ошибка проверки
main() {
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
