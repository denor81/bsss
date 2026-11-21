#!/bin/bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DNS_RESOLVED_SERVICE="systemd-resolved.service"
readonly DNS_SERVICE_POLL_SECONDS=1

UNIT_FILE_STATE="disabled"
ACTIVE_STATE="inactive"
SUB_STATE="dead"
SYSTEMCTL_FAILURE=""
SYSTEMCTL_CALLS=""
TRIGGERED_BY=""

# @type:        Sink
# @description: Fails the current test
# @params:      message Failure message (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   1 always
test::fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# @type:        Sink
# @description: Avoids focused service polling delays
# @stdin:       None
# @stdout:      None
# @exit_code:   0 always
sleep() { :; }

# @type:        Sink
# @description: Accepts focused filesystem flushes
# @stdin:       None
# @stdout:      None
# @exit_code:   0 always
sync() { :; }

# @type:        Source
# @description: Returns modeled unit properties
# @params:      service Unit name (string) without a terminator
#               property Property name (string) without a terminator
# @stdin:       None
# @stdout:      property_value\n
# @exit_code:   0 known property
#               1 unknown property
dns::state::unit_property() {
    case "$2" in
        UnitFileState) printf '%s\n' "$UNIT_FILE_STATE" ;;
        ActiveState) printf '%s\n' "$ACTIVE_STATE" ;;
        SubState) printf '%s\n' "$SUB_STATE" ;;
        TriggeredBy) printf '%s\n' "$TRIGGERED_BY" ;;
        *) return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Models systemd service transitions
# @stdin:       None
# @stdout:      None
# @exit_code:   0 modeled transition
#               1 injected or unknown command
systemctl() {
    local command="$1"

    SYSTEMCTL_CALLS+="$*"$'\n'
    [[ "$command" != "$SYSTEMCTL_FAILURE" ]] || return 1
    case "$command" in
        enable) UNIT_FILE_STATE="enabled" ;;
        start | restart)
            ACTIVE_STATE="active"
            SUB_STATE="running"
            ;;
        stop)
            ACTIVE_STATE="inactive"
            SUB_STATE="dead"
            ;;
        disable) UNIT_FILE_STATE="disabled" ;;
        *) return 1 ;;
    esac
}

source "${PROJECT_ROOT}/modules/helpers/dns/service.sh"

dns::service::enable_start ||
    test::fail "enable/start failed"
[[ "$UNIT_FILE_STATE" == "enabled" &&
    "$ACTIVE_STATE" == "active" &&
    "$SUB_STATE" == "running" ]] ||
    test::fail "enable/start produced the wrong state"

dns::service::restart ||
    test::fail "bounded restart failed"

dns::service::stop_disable ||
    test::fail "stop/disable failed"
[[ "$UNIT_FILE_STATE" == "disabled" &&
    "$ACTIVE_STATE" == "inactive" &&
    "$SUB_STATE" == "dead" ]] ||
    test::fail "stop/disable produced the wrong state"

TRIGGERED_BY="systemd-resolved-varlink.socket systemd-resolved-monitor.socket"
UNIT_FILE_STATE="enabled"
ACTIVE_STATE="active"
SUB_STATE="running"
SYSTEMCTL_CALLS=""
dns::service::stop_disable ||
    test::fail "trigger-unit stop/disable failed"
[[ "$SYSTEMCTL_CALLS" == *"disable systemd-resolved.service systemd-resolved-varlink.socket systemd-resolved-monitor.socket"* ]] ||
    test::fail "trigger units were not disabled"
[[ "$SYSTEMCTL_CALLS" == *"stop --no-block systemd-resolved.service systemd-resolved-varlink.socket systemd-resolved-monitor.socket"* ]] ||
    test::fail "trigger units were not stopped"

SYSTEMCTL_FAILURE="restart"
if dns::service::restart; then
    test::fail "restart failure was accepted"
fi

SYSTEMCTL_FAILURE=""
dns::state::unit_property() {
    printf 'activating\n'
}
if dns::service::wait_state "$DNS_RESOLVED_SERVICE" "active" "running"; then
    test::fail "service state timeout was accepted"
fi

printf 'All DNS service control tests passed\n'
