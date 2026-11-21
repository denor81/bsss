#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Reports the supported system DNS protection state

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/facade.sh"

# @type:        Orchestrator
# @description: Reports DNS protection and detected configuration issues
# @stdin:       None
# @stdout:      None
# @exit_code:   0 status reported
#               $? inspection or logging failure
main() {
    i18n::load
    dns::presentation::status
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
