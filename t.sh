#!/usr/bin/env bash
# Проверяет SSH порт
# MODULE_TYPE: check
readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"

source "${PROJECT_ROOT}/lib/vars.conf"


set -Eeuo pipefail

test() {
    local rules="123"
    [[ -z "$rules" ]] 
}

test