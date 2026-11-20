# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Проверяет наличие правил UFW BSSS
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               1 нет правил BSSS
ufw::rule::has_any_bsss() {
    ufw::rule::get_all_bsss | read -r -d '' _
}

# @type:        Sink
# @description: Creates one UFW rules backup
# @params:      source_path UFW rules file (path) without a terminator
#               backup_path BSSS backup file (path) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 backup created
#               $? copy failure
ufw::ping::backup_file() {
    local source_path="$1"
    local backup_path="$2"
    local res

    if res=$(cp -pv "$source_path" "$backup_path" 2>&1); then
        log_info "$(_ "ufw.success.backup_created" "$res")"
    else
        local rc=$?
        log_error "$(_ "ufw.error.backup_failed" "$backup_path" "$res")"
        return "$rc"
    fi
}

# @type:        Sink
# @description: Changes only the UFW input echo-request rule from ACCEPT to DROP
# @params:      path UFW rules file (path) without a terminator
#               family Rule family: ipv4 or ipv6 (string) without a terminator
# @stdin:       None
# @stdout:      None
# @exit_code:   0 rule changed and verified
#               1 edit failed, family is unsupported, or expected rule is absent
ufw::ping::disable_in_rules() {
    local path="$1"
    local family="$2"
    local chain protocol option

    case "$family" in
        ipv4)
            chain="ufw-before-input"
            protocol="icmp"
            option="--icmp-type"
            ;;
        ipv6)
            chain="ufw6-before-input"
            protocol="icmpv6"
            option="--icmpv6-type"
            ;;
        *)
            return 1
            ;;
    esac

    if sed -Ei "
        /^[[:space:]]*-A[[:space:]]+${chain}([[:space:]]|$)/ {
            /-p[[:space:]]+${protocol}([[:space:]]|$)/ {
                /${option}[[:space:]]+echo-request([[:space:]]|$)/ {
                    s/(-j[[:space:]]+)ACCEPT([[:space:]]|$)/\\1DROP\\2/
                }
            }
        }
    " "$path" && ufw::ping::rule_is "$path" "$family" "DROP"; then
        log_info "$(_ "ufw.success.before_rules_edited" "$path")"
    else
        log_error "$(_ "ufw.error.edit_failed" "$path")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Transactionally blocks IPv4 and IPv6 input echo-request rules
# @stdin:       None
# @stdout:      None
# @exit_code:   0 rules changed and UFW reloaded
#               1 existing BSSS state, backup, edit, restore, or reload failure
ufw::orchestrator::disable_ping() {
    if ufw::ping::is_configured; then
        log_error "$(_ "ufw.error.ping_state_exists")"
        return 1
    fi

    ufw::ping::backup_file "$UFW_BEFORE_RULES" "$UFW_BEFORE_RULES_BACKUP" || return
    if ! ufw::ping::backup_file "$UFW_BEFORE6_RULES" "$UFW_BEFORE6_RULES_BACKUP"; then
        ufw::ping::restore || return 1
        return 1
    fi

    if ! ufw::ping::disable_in_rules "$UFW_BEFORE_RULES" "ipv4" ||
        ! ufw::ping::disable_in_rules "$UFW_BEFORE6_RULES" "ipv6"; then
        ufw::ping::restore || return 1
        return 1
    fi

    if ! ufw::status::reload; then
        ufw::ping::restore || return 1
        ufw::status::reload || true
        return 1
    fi
}

# @type:        Orchestrator
# @description: Принудительно включает UFW
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               $? код ошибки команды ufw
ufw::status::force_enable() {
    if ufw --force enable >/dev/null 2>&1; then
        log_info "$(_ "ufw.success.enabled")"
    else
        local rc=$?
        log_error "$(_ "ufw.error.enable_failed")"
        return "$rc"
    fi
}

# @type:        Sink
# @description: Выполняет ufw reload для применения изменений
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               $? код ошибки ufw reload
ufw::status::reload() {
    if ufw reload >/dev/null; then
        log_info "$(_ "ufw.success.reloaded")"
    else
        local rc=$?
        log_error "$(_ "ufw.error.reload_failed" "$rc")"
        return "$rc"
    fi
}
