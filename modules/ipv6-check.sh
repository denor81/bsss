#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Проверяет состояние IPv6 (включен/отключен)

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/modules/helpers/ipv6.sh"

# @type:        Validator
# @description: Проверяет, отключен ли IPv6 по наличию конфигурации BSSS
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
check() {
    if ipv6::config::is_configured; then
        log_info "$(_ "ipv6.check.disabled")"
        return 0
    fi

    log_warn "$(_ "ipv6.check.enabled")"
    return 0
}

# @type:        Orchestrator
# @description: Запускает проверку IPv6
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 всегда
main() {
    i18n::load
    check
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
