#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Проверяет, настроен ли swap файл

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/swap.sh"

# @type:        Validator
# @description: Проверяет наличие настройки swap файла
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
check() {
    if swap::state::is_configured; then
        log_info "$(_ "swap.check.configured")"
        return 0
    fi

    log_warn "$(_ "swap.check.not_configured")"
    return 0
}

# @type:        Orchestrator
# @description: Запускать проверку swap файла
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
main() {
    i18n::load
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
