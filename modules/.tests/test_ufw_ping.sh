#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ../..)"
readonly TEST_TMP="$(mktemp -d)"
readonly UFW_BEFORE_RULES="${TEST_TMP}/before.rules"
readonly UFW_BEFORE_RULES_BACKUP="${TEST_TMP}/before.rules.bsss_backup"
readonly UFW_BEFORE6_RULES="${TEST_TMP}/before6.rules"
readonly UFW_BEFORE6_RULES_BACKUP="${TEST_TMP}/before6.rules.bsss_backup"
readonly ORIGINAL_V4="${TEST_TMP}/before.rules.original"
readonly ORIGINAL_V6="${TEST_TMP}/before6.rules.original"
readonly INFO_LOG="${TEST_TMP}/info.log"
readonly WARN_LOG="${TEST_TMP}/warn.log"
readonly TAB_LOG="${TEST_TMP}/tab.log"

trap 'rm -rf "$TEST_TMP"' EXIT

source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/ufw.sh"

MOCK_RELOAD_RC=0
MOCK_RELOAD_CALLS=0
: > "$INFO_LOG"
: > "$WARN_LOG"
: > "$TAB_LOG"

# @type:        Source
# @description: Returns translation keys and arguments in a deterministic test form
# @params:      key Translation key (string) without a terminator
#               ... Translation arguments without terminators
# @stdin:       None
# @stdout:      key|argument...
# @exit_code:   0 always
_() {
    local key="$1"
    shift
    printf '%s' "$key"
    printf '|%s' "$@"
}

# @type:        Sink
# @description: Captures informational logs
# @params:      message Log message (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 always
log_info() {
    printf '%s\n' "$1" >> "$INFO_LOG"
}

# @type:        Sink
# @description: Captures warning logs
# @params:      message Log message (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 always
log_warn() {
    printf '%s\n' "$1" >> "$WARN_LOG"
}

# @type:        Sink
# @description: Captures error logs
# @params:      message Log message (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 always
log_error() {
    printf '%s\n' "$1" >> "$WARN_LOG"
}

# @type:        Sink
# @description: Captures tabbed informational logs
# @params:      message Log message (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 always
log_info_simple_tab() {
    printf '%s\n' "$1" >> "$TAB_LOG"
}

# @type:        Sink
# @description: Mocks UFW reload
# @params:      args UFW arguments without terminators
# @stdin:       None
# @stdout:      None
# @exit_code:   $MOCK_RELOAD_RC
ufw() {
    [[ "$*" == "reload" ]]
    MOCK_RELOAD_CALLS=$((MOCK_RELOAD_CALLS + 1))
    return "$MOCK_RELOAD_RC"
}

# @type:        Sink
# @description: Fails the test with a message
# @params:      message Failure description (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   1 always
test::fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# @type:        Validator
# @description: Compares two files byte for byte
# @params:      expected Expected file (path) without a terminator
#               actual Actual file (path) without a terminator
#               context Assertion context (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 files match
#               1 files differ
test::assert_files() {
    cmp --silent "$1" "$2" || test::fail "$3"
}

# @type:        Sink
# @description: Writes representative default UFW IPv4 and IPv6 rule files
# @stdin:       None
# @stdout:      None
# @exit_code:   0 fixtures written
test::write_default_rules() {
    cat > "$UFW_BEFORE_RULES" << 'EOF'
*filter
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT
COMMIT
EOF
    cat > "$UFW_BEFORE6_RULES" << 'EOF'
*filter
-A ufw6-before-input -p icmpv6 --icmpv6-type destination-unreachable -j ACCEPT
-A ufw6-before-input -p icmpv6 --icmpv6-type packet-too-big -j ACCEPT
-A ufw6-before-input -p icmpv6 --icmpv6-type echo-request -j ACCEPT
-A ufw6-before-forward -p icmpv6 --icmpv6-type echo-request -j ACCEPT
COMMIT
EOF
}

test::write_default_rules
cp "$UFW_BEFORE_RULES" "$ORIGINAL_V4"
cp "$UFW_BEFORE6_RULES" "$ORIGINAL_V6"

ufw::ping::is_configured && test::fail "default rules were marked as BSSS configured"
ufw::ping::requires_restore && test::fail "default rules required manual restore"
ufw::ping::rule_is "$UFW_BEFORE_RULES" "ipv4" "ACCEPT" ||
    test::fail "default IPv4 echo-request rule was not detected"
ufw::ping::rule_is "$UFW_BEFORE6_RULES" "ipv6" "ACCEPT" ||
    test::fail "default IPv6 echo-request rule was not detected"

printf '%s\n' '-A ufw-before-input -p icmp --icmp-type echo-request -j DROP' >> "$UFW_BEFORE_RULES"
if ufw::ping::rule_is "$UFW_BEFORE_RULES" "ipv4" "ACCEPT" ||
    ufw::ping::rule_is "$UFW_BEFORE_RULES" "ipv4" "DROP"; then
    test::fail "ambiguous duplicate IPv4 rules were accepted"
fi
cp "$ORIGINAL_V4" "$UFW_BEFORE_RULES"

ufw::log::ping_status
grep -Fq 'ufw.status.ping_allowed' "$WARN_LOG" ||
    test::fail "default Ping status was not logged"
grep -Fq "${UFW_BEFORE_RULES}:-A ufw-before-input" "$TAB_LOG" ||
    test::fail "IPv4 rule path was not logged"
grep -Fq "${UFW_BEFORE6_RULES}:-A ufw6-before-input" "$TAB_LOG" ||
    test::fail "IPv6 rule path was not logged"

sed -i '/ufw-before-input .*--icmp-type echo-request/s/ACCEPT/DROP/' "$UFW_BEFORE_RULES"
sed -i '/ufw6-before-input .*--icmpv6-type echo-request/s/ACCEPT/DROP/' "$UFW_BEFORE6_RULES"
: > "$WARN_LOG"
ufw::log::ping_status
grep -Fq 'ufw.status.ping_unconfirmed' "$WARN_LOG" ||
    test::fail "foreign DROP rules were incorrectly claimed as BSSS state"
test::write_default_rules

ufw::orchestrator::disable_ping
[[ "$MOCK_RELOAD_CALLS" == "1" ]] || test::fail "successful change did not reload UFW once"
ufw::ping::is_configured || test::fail "dual-stack backups were not detected"
ufw::ping::is_legacy && test::fail "current dual-stack state was marked legacy"
ufw::ping::is_effective || test::fail "dual-stack DROP state was not detected"
ufw::ping::requires_restore && test::fail "effective dual-stack state required manual restore"
test::assert_files "$ORIGINAL_V4" "$UFW_BEFORE_RULES_BACKUP" "IPv4 backup differs from original"
test::assert_files "$ORIGINAL_V6" "$UFW_BEFORE6_RULES_BACKUP" "IPv6 backup differs from original"
grep -Fq -- '-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT' "$UFW_BEFORE_RULES" ||
    test::fail "IPv4 control ICMP rule was changed"
grep -Fq -- '-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT' "$UFW_BEFORE_RULES" ||
    test::fail "IPv4 forwarding echo-request rule was changed"
grep -Fq -- '-A ufw6-before-input -p icmpv6 --icmpv6-type packet-too-big -j ACCEPT' "$UFW_BEFORE6_RULES" ||
    test::fail "IPv6 control ICMP rule was changed"
grep -Fq -- '-A ufw6-before-forward -p icmpv6 --icmpv6-type echo-request -j ACCEPT' "$UFW_BEFORE6_RULES" ||
    test::fail "IPv6 forwarding echo-request rule was changed"

: > "$INFO_LOG"
: > "$WARN_LOG"
: > "$TAB_LOG"
ufw::log::ping_status
grep -Fq 'ufw.status.ping_blocked' "$INFO_LOG" ||
    test::fail "effective dual-stack Ping block was not logged"
grep -Fq "${UFW_BEFORE_RULES}:-A ufw-before-input -p icmp --icmp-type echo-request -j DROP" "$TAB_LOG" ||
    test::fail "effective IPv4 DROP rule was not logged"
grep -Fq "${UFW_BEFORE6_RULES}:-A ufw6-before-input -p icmpv6 --icmpv6-type echo-request -j DROP" "$TAB_LOG" ||
    test::fail "effective IPv6 DROP rule was not logged"

ufw::ping::restore
test::assert_files "$ORIGINAL_V4" "$UFW_BEFORE_RULES" "IPv4 rules were not restored"
test::assert_files "$ORIGINAL_V6" "$UFW_BEFORE6_RULES" "IPv6 rules were not restored"
[[ ! -e "$UFW_BEFORE_RULES_BACKUP" && ! -e "$UFW_BEFORE6_RULES_BACKUP" ]] ||
    test::fail "current backups remained after restore"

cp "$ORIGINAL_V4" "$UFW_BEFORE_RULES_BACKUP"
sed -i '/-p icmp/s/ACCEPT/DROP/g' "$UFW_BEFORE_RULES"
ufw::ping::is_legacy || test::fail "legacy IPv4-only backup was not detected"
ufw::ping::is_effective && test::fail "legacy state was accepted as dual-stack effective"
ufw::ping::requires_restore || test::fail "legacy state did not require manual restore"
: > "$WARN_LOG"
ufw::log::ping_status
grep -Fq 'ufw.status.ping_legacy' "$WARN_LOG" ||
    test::fail "legacy Ping warning was not logged"
ufw::ping::restore
test::assert_files "$ORIGINAL_V4" "$UFW_BEFORE_RULES" "legacy IPv4 backup was not restored"
test::assert_files "$ORIGINAL_V6" "$UFW_BEFORE6_RULES" "legacy restore changed IPv6 rules"

cp "$ORIGINAL_V6" "$UFW_BEFORE6_RULES_BACKUP"
ufw::ping::requires_restore || test::fail "partial backup state did not require manual restore"
: > "$WARN_LOG"
ufw::log::ping_status
grep -Fq 'ufw.status.ping_inconsistent' "$WARN_LOG" ||
    test::fail "partial backup state was not reported as inconsistent"
ufw::ping::restore

test::write_default_rules
MOCK_RELOAD_RC=1
MOCK_RELOAD_CALLS=0
if ufw::orchestrator::disable_ping; then
    test::fail "failed UFW reload was accepted"
fi
test::assert_files "$ORIGINAL_V4" "$UFW_BEFORE_RULES" "reload failure did not restore IPv4"
test::assert_files "$ORIGINAL_V6" "$UFW_BEFORE6_RULES" "reload failure did not restore IPv6"
[[ ! -e "$UFW_BEFORE_RULES_BACKUP" && ! -e "$UFW_BEFORE6_RULES_BACKUP" ]] ||
    test::fail "reload failure left backups behind"
[[ "$MOCK_RELOAD_CALLS" == "2" ]] || test::fail "reload recovery was not attempted"

test::write_default_rules
sed -i '/--icmpv6-type echo-request/d' "$UFW_BEFORE6_RULES"
cp "$UFW_BEFORE6_RULES" "${TEST_TMP}/before6.rules.no-echo"
MOCK_RELOAD_RC=0
MOCK_RELOAD_CALLS=0
if ufw::orchestrator::disable_ping; then
    test::fail "missing IPv6 echo-request rule was accepted"
fi
test::assert_files "$ORIGINAL_V4" "$UFW_BEFORE_RULES" "edit failure did not restore IPv4"
test::assert_files "${TEST_TMP}/before6.rules.no-echo" "$UFW_BEFORE6_RULES" "edit failure did not restore IPv6"
[[ "$MOCK_RELOAD_CALLS" == "0" ]] || test::fail "invalid rules were reloaded"

test::write_default_rules
rm "$UFW_BEFORE6_RULES"
if ufw::orchestrator::disable_ping; then
    test::fail "missing IPv6 rules file was accepted"
fi
test::assert_files "$ORIGINAL_V4" "$UFW_BEFORE_RULES" "backup failure did not restore IPv4"
[[ ! -e "$UFW_BEFORE_RULES_BACKUP" && ! -e "$UFW_BEFORE6_RULES_BACKUP" ]] ||
    test::fail "backup failure left partial backups"

printf 'UFW Ping tests passed\n'
