#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Проверяет, настроены ли автообновления

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/modules/helpers/auto-upgrades.sh"

# @type:        Validator
# @description: Проверяет наличие настройки автообновлений по файлу бэкапа
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
check() {
    if auto::upgrades::is_configured; then
        log_info "$(_ "auto.upgrades.check.configured")"
        return 0
    fi

    log_warn "$(_ "auto.upgrades.check.not_configured")"
    return 0
}

# @type:        Orchestrator
# @description: Запускать проверку автообновлений
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
