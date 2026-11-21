# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Source
# @description: Emits one machine-readable preflight blocker
# @params:      code Issue identifier (string) without a terminator
#               ... Issue arguments (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>argument...\0
# @exit_code:   0 issue emitted
#               1 malformed field
dns::check::emit() {
    local code="$1"
    local field separator=""

    shift
    [[ -n "$code" && "$code" != *[$'\t\n']* ]] || return 1
    for field in "$@"; do
        [[ "$field" != *[$'\t\n']* ]] || return 1
    done

    printf '%s\t' "$code"
    for field in "$@"; do
        printf '%s%s' "$separator" "$field"
        separator=$'\t'
    done
    printf '\0'
}

# @type:        Source
# @description: Emits one blocker and returns the preconfiguration-required status
# @params:      code Issue identifier (string) without a terminator
#               ... Issue arguments (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>argument...\0
# @exit_code:   4 blocker emitted
#               1 malformed field
dns::check::block() {
    dns::check::emit "$@" || return 1
    return 4
}

# @type:        Source
# @description: Reads the current operating system identifier and version
# @stdin:       None
# @stdout:      id<TAB>version\0
# @exit_code:   0 release emitted
#               1 release data unavailable or malformed
dns::check::release() {
    [[ -r "$OS_RELEASE_FILE_PATH" ]] || return 1
    (
        source "$OS_RELEASE_FILE_PATH"
        [[ -n "${ID-}" && -n "${VERSION_ID-}" ]] || exit 1
        [[ "$ID" != *[$'\t\n']* && "$VERSION_ID" != *[$'\t\n']* ]] || exit 1
        printf '%s\t%s\0' "$ID" "$VERSION_ID"
    )
}

# @type:        Validator
# @description: Checks release support for a detected resolver mode
# @params:      mode Resolver mode (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>argument...\0 on a blocker
# @exit_code:   0 mode supported on this release
#               1 invalid mode or release inspection failure
#               4 observed release unsupported
dns::check::compatibility() {
    local mode="$1"
    local record id version pattern supported

    case "$mode" in
        resolved-stub)
            supported="$DNS_SUPPORTED_UBUNTU_VERSIONS"
            ;;
        networkd-direct)
            supported="$DNS_BOOTSTRAP_SUPPORTED_UBUNTU_VERSIONS"
            ;;
        interrupted)
            return
            ;;
        *) return 1 ;;
    esac

    IFS= read -r -d '' record < <(dns::check::release) || return 1
    [[ "$record" == *$'\t'* && "${record#*$'\t'}" != *$'\t'* ]] || return 1
    id="${record%%$'\t'*}"
    version="${record#*$'\t'}"
    pattern="^(${supported})$"
    [[ "$id" == "ubuntu" && "$version" =~ $pattern ]] ||
        dns::check::block "unsupported_release" "$mode" "$id" "$version" "$supported"
}

# @type:        Validator
# @description: Rechecks that the observed resolver mode did not change
# @params:      expected_mode Previously detected resolver mode (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>argument...\0 on a blocker
# @exit_code:   0 mode unchanged
#               1 mode inspection failure
#               4 mode changed
dns::check::mode() {
    local expected_mode="$1"
    local actual_mode status

    if actual_mode=$(dns::mode::get | tr -d '\0'); then
        [[ "$actual_mode" == "$expected_mode" ]] ||
            dns::check::block "mode_changed" "$expected_mode" "$actual_mode"
        return
    else
        status=$?
    fi

    (( status == 4 )) ||
        return "$status"
    dns::check::block "mode_changed" "$expected_mode" "${actual_mode:-unsupported}"
}

# @type:        Validator
# @description: Checks that every required command exists
# @params:      ... Command names (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>argument\0 on a blocker
# @exit_code:   0 commands available
#               4 command missing
dns::check::commands() {
    local command

    for command in "$@"; do
        command -v "$command" >/dev/null 2>&1 ||
            dns::check::block "missing_command" "$command" ||
            return
    done
}

# @type:        Validator
# @description: Checks that the resolved drop-in directory is absent or a real directory
# @stdin:       None
# @stdout:      issue_code<TAB>path\0 on a blocker
# @exit_code:   0 directory shape safe
#               4 unsafe object
dns::check::config_dir() {
    if [[ -L "$DNS_RESOLVED_CONFIG_DIR" ||
        ( -e "$DNS_RESOLVED_CONFIG_DIR" && ! -d "$DNS_RESOLVED_CONFIG_DIR" ) ]]; then
        dns::check::block "config_dir_unsafe" "$DNS_RESOLVED_CONFIG_DIR"
    fi
}

# @type:        Validator
# @description: Checks BSSS target ownership and transient rollback state
# @stdin:       None
# @stdout:      issue_code<TAB>path\0 on a blocker
# @exit_code:   0 target state safe
#               4 stale or foreign state
dns::check::target() {
    if [[ -e "$BSSS_DNS_ROLLBACK_FILE" || -L "$BSSS_DNS_ROLLBACK_FILE" ]]; then
        dns::check::block "stale_backup" "$BSSS_DNS_ROLLBACK_FILE"
        return
    fi
    if [[ -e "$BSSS_DNS_CONFIG_FILE" || -L "$BSSS_DNS_CONFIG_FILE" ]] &&
        ! dns::config::is_owned "$BSSS_DNS_CONFIG_FILE"; then
        dns::check::block "foreign_target" "$BSSS_DNS_CONFIG_FILE"
    fi
}

# @type:        Validator
# @description: Checks preconditions for removing the BSSS resolved configuration
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 owned target can be removed
#               1 technical or internal failure
#               4 observed blocker
dns::check::remove() {
    dns::check::compatibility "resolved-stub" || return
    dns::check::mode "resolved-stub" || return
    dns::check::commands systemctl resolvectl readlink ss gawk mv cp rm sync || return
    dns::check::config_dir || return
    dns::check::target || return
    if [[ ! -e "$BSSS_DNS_CONFIG_FILE" && ! -L "$BSSS_DNS_CONFIG_FILE" ]]; then
        dns::check::block "target_absent" "$BSSS_DNS_CONFIG_FILE"
        return
    fi
    dns::config::is_owned "$BSSS_DNS_CONFIG_FILE" ||
        dns::check::block "foreign_target" "$BSSS_DNS_CONFIG_FILE"
}

# @type:        Validator
# @description: Rejects foreign local DNS listeners
# @stdin:       None
# @stdout:      issue_code<TAB>address\0 on a blocker
# @exit_code:   0 no foreign listener
#               1 listener inspection failed
#               4 foreign listener found
dns::check::local_resolver() {
    local listeners listener

    listeners=$(dns::runtime::local_resolvers | tr '\0' '\n') || return 1
    [[ -z "$listeners" ]] || {
        listener="${listeners%%$'\n'*}"
        dns::check::block "local_resolver" "$listener"
    }
}

# @type:        Validator
# @description: Rejects per-link route or search domains
# @stdin:       None
# @stdout:      issue_code<TAB>link<TAB>domain\0 on a blocker
# @exit_code:   0 no domains found
#               1 runtime inspection or parsing failed
#               4 domain found
dns::check::routes() {
    local issues issue link domain

    issues=$(dns::runtime::route_domains | tr '\0' '\n') || return 1
    [[ -z "$issues" ]] || {
        issue="${issues%%$'\n'*}"
        [[ "$issue" == *$'\t'* && "${issue#*$'\t'}" != *$'\t'* ]] || return 1
        link="${issue%%$'\t'*}"
        domain="${issue#*$'\t'}"
        dns::check::block "route_domain" "$link" "$domain"
    }
}

# @type:        Validator
# @description: Rejects later foreign drop-ins that set managed DNS values
# @stdin:       None
# @stdout:      issue_code<TAB>path\0 on a blocker
# @exit_code:   0 no conflict
#               1 inspection failure
#               4 conflict found
dns::check::late_conflict() {
    local conflicts conflict

    conflicts=$(dns::config::late_conflicts | tr '\0' '\n') || return 1
    [[ -z "$conflicts" ]] || {
        conflict="${conflicts%%$'\n'*}"
        dns::check::block "late_conflict" "$conflict"
    }
}

# @type:        Validator
# @description: Validates TLS reachability and certificate identity for one endpoint
# @params:      ip Resolver IPv4 address (string) without a terminator
#               tls_hostname TLS server name (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>ip<TAB>tls_hostname\0 on a blocker
# @exit_code:   0 endpoint validated
#               4 endpoint unavailable
dns::check::endpoint() {
    local ip="$1"
    local tls_hostname="$2"

    timeout "${DNS_ENDPOINT_TIMEOUT_SECONDS}s" openssl s_client \
        -connect "${ip}:853" \
        -servername "$tls_hostname" \
        -verify_hostname "$tls_hostname" \
        -verify_return_error \
        -brief </dev/null >/dev/null 2>&1 ||
        dns::check::block "endpoint_unavailable" "$ip" "$tls_hostname"
}

# @type:        Orchestrator
# @description: Validates every endpoint in a resolver profile
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 endpoints validated
#               1 malformed endpoint stream or unsupported profile
#               4 endpoint unavailable
dns::check::endpoints() {
    local profile="$1"
    local record="" ip tls_hostname

    dns::profile::is_valid "$profile" || return 1
    while IFS= read -r -d '' record; do
        [[ "$record" == *$'\t'* ]] || return 1
        ip="${record%%$'\t'*}"
        tls_hostname="${record#*$'\t'}"
        [[ -n "$ip" && -n "$tls_hostname" && "$tls_hostname" != *$'\t'* ]] || return 1
        dns::check::endpoint "$ip" "$tls_hostname" || return
        record=""
    done < <(dns::profile::get_endpoints "$profile")
    [[ -z "$record" ]] || return 1
}

# @type:        Validator
# @description: Validates a nameserver-only resolver file
# @params:      path Resolver file path (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 supported numeric nameservers
#               1 malformed, unsupported, or unreadable content
dns::check::direct_content() {
    gawk '
        function ipv4(value, parts, count, i) {
            count = split(value, parts, ".")
            if (count != 4) {
                return 0
            }
            for (i = 1; i <= 4; i++) {
                if (parts[i] !~ /^(0|[1-9][0-9]{0,2})$/ ||
                    parts[i] + 0 > 255) {
                    return 0
                }
            }
            return 1
        }
        function hextets(value, parts, count, i) {
            if (value == "") {
                return 0
            }
            count = split(value, parts, ":")
            for (i = 1; i <= count; i++) {
                if (parts[i] !~ /^[0-9A-Fa-f]{1,4}$/) {
                    return -1
                }
            }
            return count
        }
        function ipv6(value, separator, left, right, left_count, right_count) {
            if (value !~ /^[0-9A-Fa-f:]+$/ || value !~ /:/ ||
                value ~ /%/ || value ~ /::.*::/) {
                return 0
            }
            separator = index(value, "::")
            if (separator == 0) {
                return hextets(value) == 8
            }
            left = substr(value, 1, separator - 1)
            right = substr(value, separator + 2)
            left_count = left == "" ? 0 : hextets(left)
            right_count = right == "" ? 0 : hextets(right)
            return left_count >= 0 && right_count >= 0 &&
                left_count + right_count < 8
        }
        /^[[:space:]]*($|#)/ { next }
        {
            if (NF != 2 || $1 != "nameserver" ||
                !(ipv4($2) || ipv6($2))) {
                invalid = 1
                exit
            }
            found = 1
        }
        END { exit found && !invalid ? 0 : 1 }
    ' "$1"
}

# @type:        Validator
# @description: Validates the direct resolver file object and content
# @stdin:       None
# @stdout:      issue_code<TAB>path\0 on a blocker
# @exit_code:   0 direct resolver file safe
#               4 unsupported or ambiguous file
dns::check::direct_file() {
    local uid gid links type mount_target attributes

    [[ -f "$DNS_RESOLV_CONF_PATH" && ! -L "$DNS_RESOLV_CONF_PATH" ]] ||
        dns::check::block "resolv_conf_unsupported" "$DNS_RESOLV_CONF_PATH" ||
        return
    IFS=$'\t' read -r uid gid links type < <(
        stat -c $'%u\t%g\t%h\t%F' "$DNS_RESOLV_CONF_PATH"
    ) || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$links" == "1" && "$type" == regular*file ]] ||
        dns::check::block "resolv_conf_unsupported" "$DNS_RESOLV_CONF_PATH" ||
        return
    mount_target=$(findmnt -n -T "$DNS_RESOLV_CONF_PATH" -o TARGET) || return 1
    [[ "$mount_target" != "$DNS_RESOLV_CONF_PATH" ]] ||
        dns::check::block "resolv_conf_unsupported" "$DNS_RESOLV_CONF_PATH" ||
        return
    attributes=$(lsattr -d "$DNS_RESOLV_CONF_PATH" 2>/dev/null) || return 1
    [[ "${attributes%% *}" != *i* ]] ||
        dns::check::block "resolv_conf_unsupported" "$DNS_RESOLV_CONF_PATH" ||
        return
    dns::check::direct_content "$DNS_RESOLV_CONF_PATH" ||
        dns::check::block "resolv_conf_unsupported" "$DNS_RESOLV_CONF_PATH"
}

# @type:        Validator
# @description: Checks that the private state root is absent or secure
# @stdin:       None
# @stdout:      issue_code<TAB>path\0 on a blocker
# @exit_code:   0 state root absent or safe
#               1 metadata inspection failure
#               4 unsafe state root
dns::check::state_dir() {
    local uid gid mode mode_value

    if [[ ! -e "$BSSS_STATE_DIR" && ! -L "$BSSS_STATE_DIR" ]]; then
        return
    fi
    [[ -d "$BSSS_STATE_DIR" && ! -L "$BSSS_STATE_DIR" ]] ||
        dns::check::block "state_dir_unsafe" "$BSSS_STATE_DIR" ||
        return
    IFS=$'\t' read -r uid gid mode < <(
        stat -c $'%u\t%g\t%a' "$BSSS_STATE_DIR"
    ) || return 1
    mode_value=$((8#$mode))
    if [[ "$uid" == "0" && "$gid" == "0" ]] && (( (mode_value & 8#022) == 0 )); then
        return
    fi
    dns::check::block "state_dir_unsafe" "$BSSS_STATE_DIR"
}

# @type:        Validator
# @description: Rejects resolved kernel command-line DNS overrides
# @stdin:       None
# @stdout:      issue_code\0 on a blocker
# @exit_code:   0 no override
#               1 command line unavailable
#               4 override found
dns::check::kernel_overrides() {
    local cmdline status

    cmdline=$(< /proc/cmdline) || return 1
    if gawk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^(nameserver|domain)=/) {
                    exit 0
                }
            }
            exit 1
        }
    ' <<< "$cmdline"; then
        dns::check::block "kernel_override"
    else
        status=$?
        (( status == 1 )) || return 1
    fi
}

# @type:        Validator
# @description: Checks that the DNS test name is absent from /etc/hosts
# @stdin:       None
# @stdout:      issue_code<TAB>name\0 on a blocker
# @exit_code:   0 test name is external
#               1 hosts file unreadable
#               4 local hosts entry found
dns::check::test_name() {
    local status

    [[ -r "$HOSTS_FILE_PATH" ]] || return 1
    if gawk -v name="$DNS_TEST_DOMAIN" '
        /^[[:space:]]*($|#)/ { next }
        {
            for (i = 2; i <= NF; i++) {
                value = tolower($i)
                sub(/\.$/, "", value)
                expected = tolower(name)
                sub(/\.$/, "", expected)
                if (value == expected) {
                    found = 1
                    exit
                }
            }
        }
        END { exit found ? 0 : 1 }
    ' "$HOSTS_FILE_PATH"; then
        dns::check::block "test_name_local" "$DNS_TEST_DOMAIN"
    else
        status=$?
        (( status == 1 )) || return 1
    fi
}

# @type:        Validator
# @description: Validates direct libc DNS without changing the resolver mode
# @stdin:       None
# @stdout:      issue_code<TAB>name\0 on a blocker
# @exit_code:   0 direct query succeeded and mode stayed unchanged
#               1 mode inspection failure
#               4 query failed or mode changed
dns::check::direct_query() {
    if ! dns::runtime::query_libc "$DNS_TEST_DOMAIN"; then
        dns::check::block "direct_query_failed" "$DNS_TEST_DOMAIN"
        return
    fi
    dns::check::mode "networkd-direct"
}

# @type:        Orchestrator
# @description: Checks read-only preconditions for an existing resolved-stub mode
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 preflight passed
#               1 technical or internal failure
#               4 observed blocker
dns::check::resolved() {
    local profile="$1"

    dns::check::compatibility "resolved-stub" || return
    dns::check::mode "resolved-stub" || return
    dns::check::commands systemctl systemd-analyze resolvectl readlink ss gawk openssl timeout \
        mktemp mv cp cmp chown chmod mkdir || return
    dns::runtime::stub_is_listening ||
        dns::check::block "stub_inactive" ||
        return
    dns::check::local_resolver || return
    dns::check::config_dir || return
    dns::check::target || return
    dns::config::get_effective >/dev/null || {
        dns::check::block "effective_unavailable"
        return
    }
    dns::check::routes || return
    dns::check::late_conflict || return
    dns::check::endpoints "$profile"
}

# @type:        Orchestrator
# @description: Checks read-only preconditions for networkd-direct preparation
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 preflight passed
#               1 technical or internal failure
#               4 observed blocker
dns::check::direct() {
    local profile="$1"

    dns::check::compatibility "networkd-direct" || return
    dns::check::mode "networkd-direct" || return
    dns::check::commands systemctl systemd-analyze resolvectl readlink ss gawk openssl timeout \
        mktemp mv cp cmp chown chmod mkdir rmdir rm ln flock sync sha256sum stat findmnt \
        lsattr getent || return
    dns::check::direct_file || return
    [[ ! -e "$BSSS_DNS_CONFIG_FILE" && ! -L "$BSSS_DNS_CONFIG_FILE" &&
        ! -e "$BSSS_DNS_ROLLBACK_FILE" && ! -L "$BSSS_DNS_ROLLBACK_FILE" ]] ||
        dns::check::block "existing_dns_state" ||
        return
    dns::check::config_dir || return
    dns::check::state_dir || return
    dns::check::local_resolver || return
    dns::check::kernel_overrides || return
    dns::check::test_name || return
    dns::check::late_conflict || return
    dns::check::direct_query || return
    dns::check::endpoints "$profile"
}

# @type:        Orchestrator
# @description: Dispatches read-only apply preflight by detected resolver mode
# @params:      mode Resolver mode (string) without a terminator
#               profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      issue_code<TAB>arguments...\0 on a blocker
# @exit_code:   0 preflight passed
#               1 technical error, malformed mode, or unsupported profile
#               4 observed blocker
dns::check::apply() {
    local mode="$1"
    local profile="$2"

    dns::profile::is_valid "$profile" || return 1
    case "$mode" in
        resolved-stub) dns::check::resolved "$profile" ;;
        networkd-direct) dns::check::direct "$profile" ;;
        interrupted) dns::check::block "recovery_required" ;;
        unsupported) dns::check::block "unsupported_mode" ;;
        *) return 1 ;;
    esac
}
