# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Orchestrator
# @description: Runs one resolver operation under the shared DNS lock
# @params:      command Component function name (string) without a terminator
#               ... Component arguments (string) without a terminator
# @stdin:       None
# @stdout:      Component output
# @exit_code:   $? component status
#               1 lock open failure
#               4 lock busy
dns::orchestrator::locked() {
    local acquired=0 status

    if [[ -z "$DNS_PREPARE_LOCK_FD" ]]; then
        dns::recovery::lock || return
        acquired=1
    fi
    if "$@"; then
        status=0
    else
        status=$?
    fi
    if (( acquired == 1 )); then
        dns::recovery::unlock
    fi
    return "$status"
}

# @type:        Orchestrator
# @description: Applies a profile through the transaction for the detected mode
# @params:      mode Resolver mode (string) without a terminator
#               profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 profile applied
#               1 technical error or failed rollback
#               3 failed change rolled back
#               4 observed blocker
dns::orchestrator::apply() {
    case "$1" in
        resolved-stub)
            dns::orchestrator::locked dns::resolved::apply "$2"
            ;;
        networkd-direct)
            dns::prepare::apply "$2"
            ;;
        interrupted)
            dns::check::block "recovery_required"
            ;;
        unsupported)
            dns::check::block "unsupported_mode"
            ;;
        *)
            return 1
            ;;
    esac
}

# @type:        Orchestrator
# @description: Removes BSSS DNS configuration from a resolved-stub system
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 configuration removed
#               1 technical error or failed rollback
#               3 failed removal rolled back
#               4 observed blocker
dns::orchestrator::remove() {
    dns::orchestrator::locked dns::resolved::remove
}

# @type:        Orchestrator
# @description: Recovers the one recognized interrupted DNS transaction
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 interrupted state recovered
#               1 technical recovery failure
#               4 foreign or inconsistent state
dns::orchestrator::recover() {
    local direct_artifacts=0 snapshot=0

    dns::recovery::has_artifacts && direct_artifacts=1
    [[ -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]] && snapshot=1
    if (( direct_artifacts == 1 && snapshot == 1 )); then
        dns::check::block "recovery_inconsistent"
        return
    fi
    if (( direct_artifacts == 1 )); then
        dns::prepare::recover
        return
    fi
    if (( snapshot == 1 )); then
        dns::orchestrator::locked dns::resolved::recover
        return
    fi
    dns::check::block "recovery_inconsistent"
}

# @type:        Orchestrator
# @description: Removes BSSS DNS state during full rollback
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 DNS state absent or removed
#               1 technical error or failed rollback
#               3 failed removal rolled back
#               4 observed blocker
dns::orchestrator::dismantle() {
    if [[ ! -e "$BSSS_DNS_CONFIG_FILE" && ! -L "$BSSS_DNS_CONFIG_FILE" ]]; then
        return 0
    fi
    dns::resolved::remove
}
