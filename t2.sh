#!/usr/bin/env bash
set -Eeuo pipefail

source "./lib/vars.conf"
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"
source "${MAIN_DIR_PATH}/lib/logging.sh"

readonly TMPPATH="/tmp/file1.txt"

delete() {
    local res
    res=$(xargs -r0 rm -rfv)
    (( ${#res} > 0 )) && log_info "$res" || true
}

touch() {
    local var=
    xargs -r0 touch
}

printf '%s' "$TMPPATH" | delete