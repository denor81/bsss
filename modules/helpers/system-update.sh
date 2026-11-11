# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Source
# @description: Generates an apt update or cleanup command
# @params:      mode Optional auto or cleanup mode (string), without terminator
# @stdin:       None
# @stdout:      command\0
# @exit_code:   0 успешно
#               1 apt не найден
sys::update::get_command() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "$(_ "system.update.apt_not_found")"
        return 1
    fi

    case "${1:-}" in
        auto) printf '%s\0' "apt-get update && DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade --with-new-pkgs -y" ;;
        cleanup) printf '%s\0' "apt-get autoremove -y && apt-get clean" ;;
        *) printf '%s\0' "apt-get update && apt-get upgrade --with-new-pkgs -y" ;;
    esac
}

# @type:        Source
# @description: Formats a byte count in IEC units with one decimal place
# @params:      bytes Size (num), without terminator
# @stdin:       None
# @stdout:      size\n
# @exit_code:   0 success
#               $? numfmt failure
sys::update::format_size() {
    LC_ALL=C numfmt --to=iec-i --suffix=B --format='%.1f' --round=nearest "$1"
}

# @type:        Sink
# @description: Logs the change in available space since a reference snapshot
# @params:      reference Available bytes in the reference snapshot (num), without terminator
#               current Available bytes now (num), without terminator
#               scope Comparison scope: total or cleanup (string), without terminator
# @stdin:       None
# @stdout:      None; informational messages use the standard logger
# @exit_code:   0 success
#               $? formatting or logging failure
sys::update::log_delta() {
    local delta=$(($2 - $1)) direction="unchanged" size
    if (( delta > 0 )); then
        direction="increased"
    elif (( delta < 0 )); then
        direction="decreased"
        delta=$((-delta))
    fi
    size=$(sys::update::format_size "$delta")
    case "$3:$direction" in
        total:increased) log_info "$(_ "system.update.disk.total.increased" "$size")" ;;
        total:decreased) log_info "$(_ "system.update.disk.total.decreased" "$size")" ;;
        total:unchanged) log_info "$(_ "system.update.disk.total.unchanged")" ;;
        cleanup:increased) log_info "$(_ "system.update.disk.cleanup.increased" "$size")" ;;
        cleanup:decreased) log_info "$(_ "system.update.disk.cleanup.decreased" "$size")" ;;
        cleanup:unchanged) log_info "$(_ "system.update.disk.cleanup.unchanged")" ;;
    esac
}

# @type:        Source
# @description: Logs root filesystem usage and returns its available byte count
# @params:      stage Snapshot stage: before, after_update, or after_cleanup (string), without terminator
#               initial Optional initial available bytes (num), without terminator
#               previous Optional post-update available bytes (num), without terminator
# @stdin:       None
# @stdout:      available_bytes\0; informational messages use the standard logger
# @exit_code:   0 success
#               $? snapshot, formatting, or logging failure
sys::update::log_disk() {
    local total used available
    local -a sizes
    read -r total used available < <(LC_ALL=C df -B1 --output=size,used,avail / | gawk 'NR == 2 {print $1, $2, $3}') || return
    sizes=("$(sys::update::format_size "$total")" "$(sys::update::format_size "$used")" "$(sys::update::format_size "$available")")
    case "$1" in
        before) log_info "$(_ "system.update.disk.before" "${sizes[@]}")" ;;
        after_update) log_info "$(_ "system.update.disk.after_update" "${sizes[@]}")" ;;
        after_cleanup) log_info "$(_ "system.update.disk.after_cleanup" "${sizes[@]}")" ;;
    esac
    if [[ -n "${3:-}" ]]; then
        sys::update::log_delta "$3" "$available" "cleanup"
    fi
    if [[ -n "${2:-}" ]]; then
        sys::update::log_delta "$2" "$available" "total"
    fi
    printf '%s\0' "$available"
}

# @type:        Sink
# @description: Executes an update and optional cleanup, logging disk usage after each successful stage
# @stdin:       update_command\0[cleanup_command\0]
#               Package commands read directly from /dev/tty.
# @stdout:      None; package command output goes directly to /dev/tty
# @exit_code:   0 success
#               1 command failure or missing update command
#               $? snapshot or logging failure
sys::update::execute() {
    local update_cmd="" cleanup_cmd initial_available updated_available
    [[ ! -t 0 ]] && IFS= read -r -d '' update_cmd || return 1

    initial_available=$(sys::update::log_disk "before" | tr -d '\0')
    if ! io::command::run_terminal bash -c "$update_cmd"; then
        log_error "$(_ "system.update.error")"
        return 1
    fi
    updated_available=$(sys::update::log_disk "after_update" "$initial_available" | tr -d '\0')

    if IFS= read -r -d '' cleanup_cmd; then
        if ! io::command::run_terminal bash -c "$cleanup_cmd"; then
            log_error "$(_ "system.update.cleanup_error")"
            return 1
        fi
        sys::update::log_disk "after_cleanup" "$initial_available" "$updated_available" >/dev/null
    fi
}
