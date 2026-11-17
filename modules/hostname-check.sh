#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Reports hostname and cloud-init hostname management

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/modules/helpers/hostname.sh"

# @type:        Orchestrator
# @description: Reports the current hostname configuration
# @stdin:       None
# @stdout:      None
# @exit_code:   0 status reported
check() {
    hostname::log::status
}

# @type:        Orchestrator
# @description: Runs the hostname diagnostic module
# @stdin:       None
# @stdout:      None
# @exit_code:   0 diagnostic completed
main() {
    i18n::load
    check
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
