# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Checks whether resolver preparation artifacts exist
# @stdin:       None
# @stdout:      None
# @exit_code:   0 one or more artifacts exist
#               1 no artifacts exist
dns::recovery::has_artifacts() {
    local path
    local -a paths=(
        "$DNS_PREPARE_DIR"
        "$DNS_PREPARE_STAGING_DIR"
        "$DNS_PREPARE_CLEANUP_DIR"
        "$DNS_PREPARE_TEMP_LINK"
    )

    for path in "${paths[@]}"; do
        [[ -e "$path" || -L "$path" ]] && return
    done
    return 1
}

# @type:        Orchestrator
# @description: Acquires the nonblocking resolver preparation lock
# @stdin:       None
# @stdout:      None
# @exit_code:   0 lock acquired
#               4 another resolver preparation operation is active
#               1 lock file could not be opened
dns::recovery::lock() {
    if [[ -n "$DNS_PREPARE_LOCK_FD" ]]; then
        return
    fi

    exec {DNS_PREPARE_LOCK_FD}> "$DNS_PREPARE_LOCK_FILE" || return 1
    if ! flock -n "$DNS_PREPARE_LOCK_FD"; then
        exec {DNS_PREPARE_LOCK_FD}>&-
        DNS_PREPARE_LOCK_FD=""
        return 4
    fi
}

# @type:        Sink
# @description: Releases the resolver preparation lock
# @stdin:       None
# @stdout:      None
# @exit_code:   0 lock released or was not held
dns::recovery::unlock() {
    if [[ -n "$DNS_PREPARE_LOCK_FD" ]]; then
        exec {DNS_PREPARE_LOCK_FD}>&-
        DNS_PREPARE_LOCK_FD=""
    fi
}

# @type:        Source
# @description: Emits the direct resolver file identity used for the final source recheck
# @stdin:       None
# @stdout:      device<TAB>inode<TAB>size<TAB>uid<TAB>gid<TAB>mode<TAB>sha256\0
# @exit_code:   0 fingerprint emitted
#               1 stat or hash failure
dns::recovery::fingerprint() {
    local metadata hash

    metadata=$(stat -c $'%d\t%i\t%s\t%u\t%g\t%a' "$DNS_RESOLV_CONF_PATH") || return 1
    hash=$(sha256sum "$DNS_RESOLV_CONF_PATH") || return 1
    printf '%s\t%s\0' "$metadata" "${hash%% *}"
}

# @type:        Validator
# @description: Validates or creates the private BSSS state directory
# @stdin:       None
# @stdout:      None
# @exit_code:   0 secure state directory available
#               1 creation or validation failed
dns::recovery::ensure_state_dir() {
    local uid gid mode mode_value

    if [[ ! -e "$BSSS_STATE_DIR" && ! -L "$BSSS_STATE_DIR" ]]; then
        mkdir -m 700 "$BSSS_STATE_DIR" || return 1
    fi
    [[ -d "$BSSS_STATE_DIR" && ! -L "$BSSS_STATE_DIR" ]] || return 1

    IFS=$'\t' read -r uid gid mode < <(
        stat -c $'%u\t%g\t%a' "$BSSS_STATE_DIR"
    ) || return 1
    mode_value=$((8#$mode))
    [[ "$uid" == "0" && "$gid" == "0" ]] && (( (mode_value & 8#022) == 0 ))
}

# @type:        Source
# @description: Renders the resolver recovery manifest
# @params:      profile Resolver profile identifier (string) without a terminator
#               hash Resolver backup SHA-256 (string) without a terminator
# @stdin:       None
# @stdout:      manifest content (text\n)
# @exit_code:   0 manifest rendered
#               1 invalid profile or hash
dns::recovery::render_manifest() {
    local profile="$1"
    local hash="$2"

    dns::profile::is_valid "$profile" || return 1
    [[ "$hash" =~ ^[0-9a-f]{64}$ ]] || return 1
    printf '# %s\nschema\t1\nprofile\t%s\nsha256\t%s\n' \
        "$BSSS_MARKER_COMMENT" \
        "$profile" \
        "$hash"
}

# @type:        Source
# @description: Validates and reads one complete resolver recovery bundle
# @params:      directory Recovery bundle directory (path) without a terminator
# @stdin:       None
# @stdout:      profile<TAB>sha256\0
# @exit_code:   0 valid complete bundle
#               1 invalid or incomplete bundle
dns::recovery::read_bundle() {
    local directory="$1"
    local state="${directory}/state"
    local backup="${directory}/resolv.conf"
    local uid gid mode links type profile hash actual_hash

    [[ -d "$directory" && ! -L "$directory" ]] || return 1
    IFS=$'\t' read -r uid gid mode < <(
        stat -c $'%u\t%g\t%a' "$directory"
    ) || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$mode" == "700" ]] || return 1

    [[ -f "$state" && ! -L "$state" ]] || return 1
    IFS=$'\t' read -r uid gid mode links type < <(
        stat -c $'%u\t%g\t%a\t%h\t%F' "$state"
    ) || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$mode" == "600" &&
        "$links" == "1" && "$type" == regular*file ]] || return 1

    IFS=$'\t' read -r profile hash < <(
        gawk -F '\t' -v marker="# ${BSSS_MARKER_COMMENT}" '
            NR == 1 { valid = $0 == marker; next }
            NR == 2 { valid = valid && $0 == "schema\t1"; next }
            NR == 3 {
                valid = valid && NF == 2 && $1 == "profile" &&
                    ($2 == "google-cloudflare" || $2 == "yandex-google")
                profile = $2
                next
            }
            NR == 4 {
                valid = valid && NF == 2 && $1 == "sha256" &&
                    $2 ~ /^[0-9a-f]{64}$/
                hash = $2
                next
            }
            { valid = 0 }
            END {
                if (valid && NR == 4) {
                    print profile "\t" hash
                    exit 0
                }
                exit 1
            }
        ' "$state"
    ) || return 1

    [[ -f "$backup" && ! -L "$backup" ]] || return 1
    IFS=$'\t' read -r uid gid links type < <(
        stat -c $'%u\t%g\t%h\t%F' "$backup"
    ) || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$links" == "1" &&
        "$type" == regular*file ]] || return 1
    actual_hash=$(sha256sum "$backup") || return 1
    [[ "${actual_hash%% *}" == "$hash" ]] || return 1

    printf '%s\t%s\0' "$profile" "$hash"
}

# @type:        Validator
# @description: Checks whether a partial recovery directory is safely removable
# @params:      directory Recovery directory (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 only expected owned entries are present
#               1 foreign metadata or entries found
dns::recovery::partial_is_owned() {
    local directory="$1"
    local uid gid mode entry name links type
    local -a entries=()

    [[ -d "$directory" && ! -L "$directory" ]] || return 1
    IFS=$'\t' read -r uid gid mode < <(
        stat -c $'%u\t%g\t%a' "$directory"
    ) || return 1
    [[ "$uid" == "0" && "$gid" == "0" && "$mode" == "700" ]] || return 1

    while IFS= read -r -d '' entry; do
        entries+=("$entry")
    done < <(
        shopt -s nullglob dotglob
        for entry in "$directory"/*; do
            printf '%s\0' "$entry"
        done
    )
    for entry in "${entries[@]}"; do
        name="${entry##*/}"
        [[ "$name" == "state" || "$name" == "resolv.conf" ]] || return 1
        [[ -f "$entry" && ! -L "$entry" ]] || return 1
        IFS=$'\t' read -r uid gid mode links type < <(
            stat -c $'%u\t%g\t%a\t%h\t%F' "$entry"
        ) || return 1
        [[ "$uid" == "0" && "$gid" == "0" && "$links" == "1" &&
            "$type" == regular*file ]] || return 1
        [[ "$name" != "state" || "$mode" == "600" ]] || return 1
    done
}

# @type:        Sink
# @description: Removes an exact owned partial recovery directory
# @params:      directory Recovery directory (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 exact owned entries removed
#               1 foreign state or deletion failure
dns::recovery::remove_partial() {
    local directory="$1"

    dns::recovery::partial_is_owned "$directory" || return 1
    if [[ -e "${directory}/state" ]]; then
        rm -- "${directory}/state" || return 1
    fi
    if [[ -e "${directory}/resolv.conf" ]]; then
        rm -- "${directory}/resolv.conf" || return 1
    fi
    rmdir -- "$directory"
}

# @type:        Sink
# @description: Removes the exact owned temporary resolv.conf symlink
# @stdin:       None
# @stdout:      None
# @exit_code:   0 owned link removed or absent
#               1 foreign object found or deletion failed
dns::recovery::remove_temp_link() {
    if [[ ! -e "$DNS_PREPARE_TEMP_LINK" && ! -L "$DNS_PREPARE_TEMP_LINK" ]]; then
        return
    fi
    [[ -L "$DNS_PREPARE_TEMP_LINK" &&
        "$(readlink "$DNS_PREPARE_TEMP_LINK")" == "$DNS_RESOLVED_STUB_PATH" ]] ||
        return 1
    rm -- "$DNS_PREPARE_TEMP_LINK"
}

# @type:        Orchestrator
# @description: Publishes a short-lived durable resolver recovery bundle
# @params:      profile Resolver profile identifier (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 durable bundle published
#               1 creation, validation, flush, or rename failed
dns::recovery::create_bundle() {
    local profile="$1"
    local hash

    dns::recovery::ensure_state_dir || return 1
    if dns::recovery::has_artifacts; then
        return 1
    fi

    (
        umask 077
        mkdir -m 700 "$DNS_PREPARE_STAGING_DIR" || exit 1
        cp -a -- "$DNS_RESOLV_CONF_PATH" "${DNS_PREPARE_STAGING_DIR}/resolv.conf" ||
            exit 1
        hash=$(sha256sum "${DNS_PREPARE_STAGING_DIR}/resolv.conf") || exit 1
        dns::recovery::render_manifest "$profile" "${hash%% *}" \
            > "${DNS_PREPARE_STAGING_DIR}/state" ||
            exit 1
        chown root:root "${DNS_PREPARE_STAGING_DIR}/state" || exit 1
        chmod 600 "${DNS_PREPARE_STAGING_DIR}/state" || exit 1
        dns::recovery::read_bundle "$DNS_PREPARE_STAGING_DIR" >/dev/null || exit 1
        sync -f "$DNS_PREPARE_STAGING_DIR" || exit 1
        mv -T "$DNS_PREPARE_STAGING_DIR" "$DNS_PREPARE_DIR" || exit 1
        sync -f "$BSSS_STATE_DIR"
    ) || return 1
}

# @type:        Sink
# @description: Removes a complete bundle after a validated outcome
# @stdin:       None
# @stdout:      None
# @exit_code:   0 bundle durably removed
#               1 validation, rename, flush, or deletion failed
dns::recovery::cleanup_bundle() {
    dns::recovery::read_bundle "$DNS_PREPARE_DIR" >/dev/null || return 1
    [[ ! -e "$DNS_PREPARE_CLEANUP_DIR" && ! -L "$DNS_PREPARE_CLEANUP_DIR" ]] ||
        return 1
    mv -T "$DNS_PREPARE_DIR" "$DNS_PREPARE_CLEANUP_DIR" || return 1
    sync -f "$BSSS_STATE_DIR" || return 1
    dns::recovery::remove_partial "$DNS_PREPARE_CLEANUP_DIR" || return 1
    sync -f "$BSSS_STATE_DIR"
}

# @type:        Sink
# @description: Atomically restores the direct resolver file from the recovery bundle
# @stdin:       None
# @stdout:      None
# @exit_code:   0 durable exact file restored
#               1 bundle, copy, rename, flush, or metadata validation failed
dns::recovery::restore_resolv_conf() {
    local bundle profile hash temporary expected actual
    local resolv_dir="${DNS_RESOLV_CONF_PATH%/*}"

    IFS= read -r -d '' bundle < <(
        dns::recovery::read_bundle "$DNS_PREPARE_DIR"
    ) || return 1
    [[ "$bundle" == *$'\t'* && "${bundle#*$'\t'}" != *$'\t'* ]] || return 1
    profile="${bundle%%$'\t'*}"
    hash="${bundle#*$'\t'}"
    dns::profile::is_valid "$profile" || return 1

    temporary=$(mktemp "${resolv_dir}/.resolv.conf.bsss_restore.XXXXXX") ||
        return 1
    if ! cp -a -- "$DNS_PREPARE_BACKUP_FILE" "$temporary"; then
        rm -f -- "$temporary" || true
        return 1
    fi
    actual=$(sha256sum "$temporary") || {
        rm -f -- "$temporary" || true
        return 1
    }
    [[ "${actual%% *}" == "$hash" ]] || {
        rm -f -- "$temporary" || true
        return 1
    }
    expected=$(stat -c $'%s\t%u\t%g\t%a' "$DNS_PREPARE_BACKUP_FILE") || {
        rm -f -- "$temporary" || true
        return 1
    }
    actual=$(stat -c $'%s\t%u\t%g\t%a' "$temporary") || {
        rm -f -- "$temporary" || true
        return 1
    }
    [[ "$actual" == "$expected" ]] || {
        rm -f -- "$temporary" || true
        return 1
    }

    if ! mv -T "$temporary" "$DNS_RESOLV_CONF_PATH"; then
        rm -f -- "$temporary" || true
        return 1
    fi
    sync -f "$resolv_dir" || return 1
    [[ -f "$DNS_RESOLV_CONF_PATH" && ! -L "$DNS_RESOLV_CONF_PATH" ]] || return 1
    actual=$(sha256sum "$DNS_RESOLV_CONF_PATH") || return 1
    [[ "${actual%% *}" == "$hash" ]] || return 1
    actual=$(stat -c $'%s\t%u\t%g\t%a' "$DNS_RESOLV_CONF_PATH") || return 1
    [[ "$actual" == "$expected" ]]
}
