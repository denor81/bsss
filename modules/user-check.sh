#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Проверяет состояние пользователей системы

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"

# @type:        Orchestrator
# @description: Запускает проверку пользователей системы
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 проверка прошла успешно
#               1 критическая ошибка
#               2 отмена пользователем
#               $? другие не определенные ошибки
main() {
    i18n::load
    user::info::block
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
