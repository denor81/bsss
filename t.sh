#!/usr/bin/env bash
# Проверяет SSH порт
# MODULE_TYPE: check
readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"

source "${PROJECT_ROOT}/lib/vars.conf"


set -Eeuo pipefail
shopt -s nullglob
files=("${SSH_CONFIGD_DIR}/"*.confs)
echo $?
(( ${#files[@]} > 0 )) && printf '%s\0' "${files[@]}"
echo $?