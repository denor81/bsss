#!/usr/bin/env bash

source "./lib/vars.conf"
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"

_get_os_id() {
    awk -F= '
        $1=="ID" {
            gsub (/"/, "", $2)
            print $2
            exit
        }
    '
}

_get_os_id < "$OS_RELEASE_FILE_PATH"