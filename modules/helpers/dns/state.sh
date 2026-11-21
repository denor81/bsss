# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Source
# @description: Reads one systemd unit property used for DNS mode detection
# @params:      service Unit name (string) without a terminator
#               property Property name (string) without a terminator
# @stdin:       None
# @stdout:      property_value\n
# @exit_code:   0 property read
#               $? systemctl failure
dns::state::unit_property() {
    systemctl show "$1" --property="$2" --value 2>/dev/null
}

# @type:        Validator
# @description: Checks whether resolver preparation artifacts exist
# @stdin:       None
# @stdout:      None
# @exit_code:   0 one or more artifacts exist
#               1 no artifacts exist
dns::mode::has_artifacts() {
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

# @type:        Source
# @description: Emits one normalized DNS mode fact
# @params:      key Fact identifier (string) without a terminator
#               value Fact value (string) without a terminator
# @stdin:       None
# @stdout:      key<TAB>value\0
# @exit_code:   0 fact emitted
#               1 malformed key or value
dns::mode::emit_fact() {
    local key="$1"
    local value="$2"

    [[ -n "$key" && "$key" != *[$'\t\n']* && "$value" != *[$'\t\n']* ]] || return 1
    printf '%s\t%s\0' "$key" "$value"
}

# @type:        Source
# @description: Emits the normalized facts required to classify the DNS mode
# @stdin:       None
# @stdout:      key<TAB>value\0 records
# @exit_code:   0 facts emitted
#               1 required system state could not be inspected
dns::mode::facts() {
    if dns::mode::has_artifacts; then
        dns::mode::emit_fact "prepare_artifacts" "yes"
        return
    fi
    dns::mode::emit_fact "prepare_artifacts" "no" || return 1

    local resolv_conf_type resolv_conf_target="unavailable"
    if [[ -L "$DNS_RESOLV_CONF_PATH" ]]; then
        resolv_conf_type="symlink"
        resolv_conf_target=$(readlink -f "$DNS_RESOLV_CONF_PATH") || resolv_conf_target="unresolved"
    elif [[ -f "$DNS_RESOLV_CONF_PATH" ]]; then
        resolv_conf_type="regular"
    elif [[ -e "$DNS_RESOLV_CONF_PATH" ]]; then
        resolv_conf_type="other"
    else
        resolv_conf_type="missing"
    fi

    local resolved_active
    resolved_active=$(dns::state::unit_property "$DNS_RESOLVED_SERVICE" "ActiveState") || return 1

    dns::mode::emit_fact "resolv_conf_type" "$resolv_conf_type" || return 1
    dns::mode::emit_fact "resolv_conf_target" "$resolv_conf_target" || return 1
    dns::mode::emit_fact "resolved_active" "$resolved_active" || return 1

    if [[ "$resolv_conf_type" != "regular" ]]; then
        return
    fi

    local resolved_load resolved_enabled resolved_substate
    local networkd_active networkd_substate network_manager_active
    resolved_load=$(dns::state::unit_property "$DNS_RESOLVED_SERVICE" "LoadState") || return 1
    resolved_enabled=$(dns::state::unit_property "$DNS_RESOLVED_SERVICE" "UnitFileState") || return 1
    resolved_substate=$(dns::state::unit_property "$DNS_RESOLVED_SERVICE" "SubState") || return 1
    networkd_active=$(dns::state::unit_property "$DNS_NETWORKD_SERVICE" "ActiveState") || return 1
    networkd_substate=$(dns::state::unit_property "$DNS_NETWORKD_SERVICE" "SubState") || return 1
    network_manager_active=$(dns::state::unit_property "$DNS_NETWORK_MANAGER_SERVICE" "ActiveState") || return 1

    dns::mode::emit_fact "resolved_load" "$resolved_load" || return 1
    dns::mode::emit_fact "resolved_enabled" "$resolved_enabled" || return 1
    dns::mode::emit_fact "resolved_substate" "$resolved_substate" || return 1
    dns::mode::emit_fact "networkd_active" "$networkd_active" || return 1
    dns::mode::emit_fact "networkd_substate" "$networkd_substate" || return 1
    dns::mode::emit_fact "network_manager_active" "$network_manager_active"
}

# @type:        Filter
# @description: Classifies normalized DNS mode facts without inspecting or mutating the system
# @stdin:       key<TAB>value\0 records
# @stdout:      resolved-stub|networkd-direct|interrupted|unsupported\0
# @exit_code:   0 mode classified
#               1 malformed, duplicate, or incomplete facts
dns::mode::detect() {
    local record="" key value
    local -A facts=()

    while IFS= read -r -d '' record; do
        [[ "$record" == *$'\t'* ]] || return 1
        key="${record%%$'\t'*}"
        value="${record#*$'\t'}"
        [[ -n "$key" && "$key" != *$'\n'* && "$value" != *[$'\t\n']* ]] || return 1
        case "$key" in
            prepare_artifacts | resolv_conf_type | resolv_conf_target | resolved_active | \
                resolved_load | resolved_enabled | resolved_substate | \
                networkd_active | networkd_substate | network_manager_active) ;;
            *) return 1 ;;
        esac
        [[ ! -v "facts[$key]" ]] || return 1
        facts["$key"]="$value"
        record=""
    done
    [[ -z "$record" ]] || return 1

    [[ -v "facts[prepare_artifacts]" ]] || return 1
    if [[ "${facts[prepare_artifacts]}" == "yes" ]]; then
        printf 'interrupted\0'
        return
    fi
    [[ "${facts[prepare_artifacts]}" == "no" ]] || return 1

    local required
    for required in resolv_conf_type resolv_conf_target resolved_active; do
        [[ -v "facts[$required]" ]] || return 1
    done

    if [[ "${facts[resolv_conf_type]}" == "symlink" &&
        "${facts[resolv_conf_target]}" == "$DNS_RESOLVED_STUB_PATH" &&
        "${facts[resolved_active]}" == "active" ]]; then
        printf 'resolved-stub\0'
        return
    fi

    if [[ "${facts[resolv_conf_type]}" == "regular" ]]; then
        for required in \
            resolved_load resolved_enabled resolved_substate \
            networkd_active networkd_substate network_manager_active; do
            [[ -v "facts[$required]" ]] || return 1
        done

        if [[ "${facts[resolved_load]}" == "loaded" &&
            "${facts[resolved_enabled]}" == "disabled" &&
            "${facts[resolved_active]}" == "inactive" &&
            "${facts[resolved_substate]}" == "dead" &&
            "${facts[networkd_active]}" == "active" &&
            "${facts[networkd_substate]}" == "running" &&
            "${facts[network_manager_active]}" != "active" &&
            "${facts[network_manager_active]}" != "activating" ]]; then
            printf 'networkd-direct\0'
            return
        fi
    fi

    printf 'unsupported\0'
}
