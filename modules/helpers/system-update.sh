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
    LC_ALL=C numfmt --to=iec-i --suffix=B --format='%.1f' --round=nearest -- "$1"
}

# @type:        Source
# @description: Reads root filesystem sizes in bytes without logging or formatting
# @stdin:       None
# @stdout:      total_bytes used_bytes available_bytes\0
# @exit_code:   0 success
#               $? df or gawk failure
sys::update::get_disk_stats() {
    LC_ALL=C df -B1 --output=size,used,avail / | gawk 'NR == 2 { printf "%s %s %s\0", $1, $2, $3 }'
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

# @type:        Sink
# @description: Logs a root filesystem snapshot with human-readable sizes
# @params:      stage Snapshot stage: before, after_update, or after_cleanup (string), without terminator
#               total Total bytes (num), without terminator
#               used Used bytes (num), without terminator
#               available Available bytes (num), without terminator
# @stdin:       None
# @stdout:      None; informational messages use the standard logger
# @exit_code:   0 success
#               $? formatting or logging failure
sys::update::log_disk() {
    local total used available
    total=$(sys::update::format_size "$2")
    used=$(sys::update::format_size "$3")
    available=$(sys::update::format_size "$4")
    case "$1" in
        before) log_info "$(_ "system.update.disk.before" "$total" "$used" "$available")" ;;
        after_update) log_info "$(_ "system.update.disk.after_update" "$total" "$used" "$available")" ;;
        after_cleanup) log_info "$(_ "system.update.disk.after_cleanup" "$total" "$used" "$available")" ;;
    esac
}

# @type:        Sink
# @description: Executes one package command without changing the surrounding workflow
# @params:      mode Optional cleanup mode for the error message (string), without terminator
# @stdin:       command\0
#               Package commands read directly from /dev/tty.
# @stdout:      None; package command output goes directly to /dev/tty
# @exit_code:   0 success
#               1 command failure or missing update command
sys::update::execute() {
    local update_cmd=""
    [[ ! -t 0 ]] && IFS= read -r -d '' update_cmd || return 1

    if ! io::command::run_terminal bash -c "$update_cmd"; then
        if [[ "${1:-}" == "cleanup" ]]; then
            log_error "$(_ "system.update.cleanup_error")"
        else
            log_error "$(_ "system.update.error")"
        fi
        return 1
    fi
}
