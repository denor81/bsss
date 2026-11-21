# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Orchestrator
# @description: Waits for an exact systemd unit runtime state
# @params:      service Unit name (string) without a terminator
#               active_state Expected ActiveState (string) without a terminator
#               sub_state Expected SubState (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 expected state reached
#               1 timeout or property inspection failure
dns::service::wait_state() {
    local service="$1"
    local expected_active="$2"
    local expected_sub="$3"
    local attempts=$((DNS_SERVICE_POLL_SECONDS * 4))
    local active sub attempt

    for (( attempt = 0; attempt < attempts; attempt++ )); do
        active=$(dns::state::unit_property "$service" "ActiveState") || return 1
        sub=$(dns::state::unit_property "$service" "SubState") || return 1
        if [[ "$active" == "$expected_active" && "$sub" == "$expected_sub" ]]; then
            return
        fi
        sleep 0.25
    done
    return 1
}

# @type:        Sink
# @description: Enables and starts systemd-resolved with bounded state polling
# @stdin:       None
# @stdout:      None
# @exit_code:   0 service enabled and running
#               1 enable, flush, start, or state validation failed
dns::service::enable_start() {
    local unit_state

    systemctl enable "$DNS_RESOLVED_SERVICE" || return 1
    unit_state=$(dns::state::unit_property "$DNS_RESOLVED_SERVICE" "UnitFileState") ||
        return 1
    [[ "$unit_state" == "enabled" ]] || return 1
    sync -f /etc/systemd/system || return 1

    systemctl start --no-block "$DNS_RESOLVED_SERVICE" || return 1
    dns::service::wait_state "$DNS_RESOLVED_SERVICE" "active" "running"
}

# @type:        Sink
# @description: Restarts systemd-resolved with bounded state polling
# @stdin:       None
# @stdout:      None
# @exit_code:   0 service running
#               1 restart or state validation failed
dns::service::restart() {
    systemctl restart --no-block "$DNS_RESOLVED_SERVICE" || return 1
    dns::service::wait_state "$DNS_RESOLVED_SERVICE" "active" "running"
}

# @type:        Sink
# @description: Stops and disables systemd-resolved with bounded state polling
# @stdin:       None
# @stdout:      None
# @exit_code:   0 service disabled and inactive
#               1 stop, disable, flush, or state validation failed
dns::service::stop_disable() {
    local unit_state

    systemctl stop --no-block "$DNS_RESOLVED_SERVICE" || return 1
    dns::service::wait_state "$DNS_RESOLVED_SERVICE" "inactive" "dead" ||
        return 1

    systemctl disable "$DNS_RESOLVED_SERVICE" || return 1
    unit_state=$(dns::state::unit_property "$DNS_RESOLVED_SERVICE" "UnitFileState") ||
        return 1
    [[ "$unit_state" == "disabled" ]] || return 1
    sync -f /etc/systemd/system
}
