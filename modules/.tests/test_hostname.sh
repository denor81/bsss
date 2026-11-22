#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ../..)"
source "${PROJECT_ROOT}/modules/helpers/hostname.sh"

# @type:        Orchestrator
# @description: Tests hostname validation, hosts transformation, and cloud-init precedence
# @stdin:       None
# @stdout:      result\n
# @exit_code:   0 all tests passed
#               1 assertion failed
main() {
    local hostname
    for hostname in server server-01 a 1 a1; do
        hostname::name::is_valid "$hostname"
    done
    for hostname in Server server_01 -server server- "server name" "server.example" ""; do
        if hostname::name::is_valid "$hostname"; then
            printf 'Unexpected valid hostname: %s\n' "$hostname" >&2
            return 1
        fi
    done

    hostname=$(printf 'a%.0s' {1..63})
    hostname::name::is_valid "$hostname"
    hostname="${hostname}a"
    if hostname::name::is_valid "$hostname"; then
        printf 'Hostname longer than 63 characters accepted\n' >&2
        return 1
    fi

    local hosts_result
    hosts_result=$(printf '127.0.0.1 localhost\n127.0.1.1 old.example.test old alias\n' | hostname::hosts::replace old server-01)
    grep -Fxq $'127.0.1.1\tserver-01.example.test\tserver-01\talias' <<< "$hosts_result"
    hostname::hosts::contains server-01 <<< "$hosts_result"
    if hostname::hosts::contains old <<< "$hosts_result"; then
        printf 'Old hostname remained mapped\n' >&2
        return 1
    fi

    hosts_result=$(printf '127.0.0.1 localhost\n' | hostname::hosts::replace old server-01)
    grep -Fxq $'127.0.1.1\tserver-01' <<< "$hosts_result"
    hostname::hosts::contains server-01 <<< "$hosts_result"

    local test_dir
    test_dir=$(mktemp -d "${TMPDIR:-/tmp}/bsss-hostname-tests.XXXXXX")
    trap "rm -rf '$test_dir'" EXIT
    CLOUD_INIT_CONFIG_FILE="${test_dir}/cloud.cfg"
    CLOUD_INIT_CONFIGD_DIR="${test_dir}/cloud.cfg.d"
    mkdir -p "$CLOUD_INIT_CONFIGD_DIR"
    printf 'preserve_hostname: false\n' > "$CLOUD_INIT_CONFIG_FILE"
    printf 'preserve_hostname: true\n' > "${CLOUD_INIT_CONFIGD_DIR}/99-bsss.cfg"
    [[ "$(hostname::cloud_init::get_preserve_setting | tr -d '\0')" == "true" ]]
    printf 'preserve_hostname: false\n' > "${CLOUD_INIT_CONFIGD_DIR}/99-z.cfg"
    [[ "$(hostname::cloud_init::get_preserve_setting | tr -d '\0')" == "false" ]]
    rm -f "$CLOUD_INIT_CONFIG_FILE" "${CLOUD_INIT_CONFIGD_DIR}/"*.cfg
    [[ "$(hostname::cloud_init::get_preserve_setting | tr -d '\0')" == "unset" ]]

    local info_log="${test_dir}/info.log"
    local tab_log="${test_dir}/tab.log"
    local warn_log="${test_dir}/warn.log"
    local warn_tab_log="${test_dir}/warn-tab.log"
    local hostname_call_log="${test_dir}/hostname-call.log"
    local preserve_setting="true"
    : > "$info_log"
    : > "$tab_log"
    : > "$warn_log"
    : > "$warn_tab_log"
    : > "$hostname_call_log"

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
    # @description: Captures informational status logs
    # @params:      message Log message (string) without a terminator
    # @stdin:       None
    # @stdout:      None
    # @exit_code:   0 always
    log_info() {
        printf '%s\n' "$1" >> "$info_log"
    }

    # @type:        Sink
    # @description: Captures tabbed informational status logs
    # @params:      message Log message (string) without a terminator
    # @stdin:       None
    # @stdout:      None
    # @exit_code:   0 always
    log_info_simple_tab() {
        printf '%s\n' "$1" >> "$tab_log"
    }

    # @type:        Sink
    # @description: Captures warning status logs
    # @params:      message Log message (string) without a terminator
    # @stdin:       None
    # @stdout:      None
    # @exit_code:   0 always
    log_warn() {
        printf '%s\n' "$1" >> "$warn_log"
    }

    # @type:        Sink
    # @description: Captures tabbed warning status logs
    # @params:      message Log message (string) without a terminator
    # @stdin:       None
    # @stdout:      None
    # @exit_code:   0 always
    log_warn_simple_tab() {
        printf '%s\n' "$1" >> "$warn_tab_log"
    }

    # @type:        Source
    # @description: Mocks the active short hostname
    # @stdin:       None
    # @stdout:      hostname\n
    # @exit_code:   0 always
    hostname::name::get_current() {
        printf 'server-01\n'
    }

    # @type:        Validator
    # @description: Mocks detected cloud-init
    # @stdin:       None
    # @stdout:      None
    # @exit_code:   0 always
    hostname::cloud_init::is_installed() {
        return 0
    }

    # @type:        Source
    # @description: Mocks an effective cloud-init preserve setting
    # @stdin:       None
    # @stdout:      setting\0
    # @exit_code:   0 always
    hostname::cloud_init::get_preserve_setting() {
        printf '%s\0' "$preserve_setting"
    }

    # @type:        Sink
    # @description: Records unexpected direct hostname command calls
    # @stdin:       None
    # @stdout:      None
    # @exit_code:   1 always
    hostname() {
        printf 'called\n' >> "$hostname_call_log"
        return 1
    }

    HOSTNAME_FILE_PATH="${test_dir}/hostname"
    HOSTS_FILE_PATH="${test_dir}/hosts"
    CLOUD_INIT_DISABLED_FILE="${test_dir}/cloud-init.disabled"
    printf 'server-01\n' > "$HOSTNAME_FILE_PATH"
    printf '127.0.0.1 localhost\n127.0.1.1 user server-01\n' > "$HOSTS_FILE_PATH"

    hostname::log::status
    grep -Fq 'hostname.check.active|server-01' "$info_log"
    grep -Fq "hostname.check.hostname_file|$HOSTNAME_FILE_PATH" "$info_log"
    grep -Fq 'no_translate|server-01' "$tab_log"
    grep -Fq "hostname.check.hosts_file|$HOSTS_FILE_PATH" "$info_log"
    grep -Fq $'no_translate|127.0.1.1 user server-01' "$tab_log"
    grep -Fq 'hostname.cloud_init.installed' "$info_log"
    grep -Fq 'hostname.cloud_init.setting|true' "$tab_log"
    [[ ! -s "$hostname_call_log" ]]

    : > "$warn_log"
    : > "$HOSTNAME_FILE_PATH"
    hostname::log::status
    grep -Fq "hostname.check.hostname_file_empty|$HOSTNAME_FILE_PATH" "$warn_log"

    : > "$warn_log"
    rm -f "$HOSTNAME_FILE_PATH" "$HOSTS_FILE_PATH"
    hostname::log::status
    grep -Fq "hostname.check.file_missing|$HOSTNAME_FILE_PATH" "$warn_log"
    grep -Fq "hostname.check.file_missing|$HOSTS_FILE_PATH" "$warn_log"

    : > "$warn_log"
    printf 'server-01\n' > "$HOSTNAME_FILE_PATH"
    printf '127.0.0.1 localhost\n' > "$HOSTS_FILE_PATH"
    hostname::log::status
    grep -Fq "hostname.check.hosts_entry_missing|$HOSTS_FILE_PATH" "$warn_log"

    : > "$tab_log"
    touch "$CLOUD_INIT_DISABLED_FILE"
    hostname::log::status
    grep -Fq "hostname.cloud_init.disabled|$CLOUD_INIT_DISABLED_FILE" "$tab_log"
    if grep -Fq 'hostname.cloud_init.setting' "$tab_log"; then
        printf 'Disabled cloud-init still logged preserve_hostname\n' >&2
        return 1
    fi

    rm "$CLOUD_INIT_DISABLED_FILE"
    preserve_setting="false"
    : > "$warn_tab_log"
    hostname::log::status
    grep -Fq 'hostname.cloud_init.setting|false' "$warn_tab_log"

    hostname::state::is_configured() {
        return 1
    }
    if ! hostname::orchestrator::restore; then
        printf 'Unconfigured hostname restore returned failure\n' >&2
        return 1
    fi

    printf 'Hostname tests passed\n'
}

main "$@"
