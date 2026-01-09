#!/usr/bin/env bash
# Изменяет SSH порт
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MAIN_DIR_PATH}/lib/vars.conf"
source "${MAIN_DIR_PATH}/lib/logging.sh"
source "${MAIN_DIR_PATH}/lib/user_confirmation.sh"
source "${MAIN_DIR_PATH}/modules/common-helpers.sh"

orchestrator::dispatch_logic() {
    if [[ -z "$(sys::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK")" ]]; then
        log_info "Настройки SSH ${UTIL_NAME^^} не найдены"
        # orchestrator::bsss_config_not_exists
    else
        log_info "Настройки SSH ${UTIL_NAME^^}"
        # orchestrator::bsss_config_exists
    fi
}

orchestrator::dispatch_logic