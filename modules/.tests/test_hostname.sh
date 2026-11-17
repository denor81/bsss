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

    printf 'Hostname tests passed\n'
}

main "$@"
