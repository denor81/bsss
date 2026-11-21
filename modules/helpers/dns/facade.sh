# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

source "${PROJECT_ROOT}/modules/helpers/dns/state.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/service.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/config.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/runtime.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/check.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/validate.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/resolved.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/recovery.sh"
source "${PROJECT_ROOT}/modules/helpers/dns/prepare.sh"

# @type:        Orchestrator
# @description: Returns the DNS mode through the new component pipeline
# @stdin:       None
# @stdout:      resolved-stub|networkd-direct|interrupted|unsupported\0
# @exit_code:   0 mode classified
#               1 required system state could not be inspected or normalized
#               4 observed state is unsupported
dns::mode::get() {
    local mode

    mode=$(dns::mode::facts | dns::mode::detect | tr -d '\0') || return
    printf '%s\0' "$mode"
    if [[ "$mode" == "unsupported" ]]; then
        return 4
    fi
}
