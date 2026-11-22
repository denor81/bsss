#!/usr/bin/env bash

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ../..)"
readonly TEST_TMP_DIR="$(mktemp -d)"
readonly RU_GUIDE="${PROJECT_ROOT}/docs/preconfiguration/ru.txt"
readonly EN_GUIDE="${PROJECT_ROOT}/docs/preconfiguration/en.txt"

trap 'rm -rf "$TEST_TMP_DIR"' EXIT

test::fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for guide in "$RU_GUIDE" "$EN_GUIDE"; do
    [[ -s "$guide" ]] || test::fail "guide missing or empty: $guide"
    if gawk 'length($0) > 78 { print NR ":" length($0) ":" $0; failed=1 } END { exit failed }' "$guide"; then
        :
    else
        test::fail "guide contains a line longer than 78 characters: $guide"
    fi
    ! grep -n $'\t' "$guide" || test::fail "guide contains a TAB: $guide"
done

ru_ids=$(grep -oE '^PRE-[A-Z0-9-]+' "$RU_GUIDE" | sort)
en_ids=$(grep -oE '^PRE-[A-Z0-9-]+' "$EN_GUIDE" | sort)
[[ "$ru_ids" == "$en_ids" ]] || test::fail "localized guide identifiers differ"

source "${PROJECT_ROOT}/modules/helpers/common.sh"
i18n::detect_language() {
    printf 'ru\n'
}

exec 3> "${TEST_TMP_DIR}/fd3"
common::preconfiguration::show > "${TEST_TMP_DIR}/stdout"
exec 3>&-

cmp -s "$RU_GUIDE" "${TEST_TMP_DIR}/fd3" ||
    test::fail "guide was not written unchanged to FD3"
[[ ! -s "${TEST_TMP_DIR}/stdout" ]] ||
    test::fail "guide polluted stdout"

printf 'PASS: preconfiguration guide\n'
