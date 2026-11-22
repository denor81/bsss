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
    ! grep -nE '^PRE-[A-Z0-9-]+' "$guide" ||
        test::fail "guide exposes internal blocker identifiers: $guide"
    ! grep -nE '^---- .*[^ ]$' "$guide" | grep -v ' # ' ||
        test::fail "diagnostic command lacks an inline comment: $guide"
    [[ "$(grep -c '^$' "$guide" || true)" == "6" ]] ||
        test::fail "guide blocks are not separated by one blank line: $guide"
done

ru_shape=$(gawk '/^-/{ match($0, /^-+/); print RLENGTH }' "$RU_GUIDE")
en_shape=$(gawk '/^-/{ match($0, /^-+/); print RLENGTH }' "$EN_GUIDE")
[[ "$ru_shape" == "$en_shape" ]] ||
    test::fail "localized guide hierarchy differs"

ru_headings=(
    "ОБЩИЕ ДЕЙСТВИЯ"
    "SSH DROP-IN НЕ ПОДКЛЮЧЕН"
    "СТОРОННИЙ SSH PORT"
    "ОТДЕЛЬНЫЙ DNS-ДОМЕН ИНТЕРФЕЙСА"
    "БОЛЕЕ ПОЗДНИЙ RESOLVED DROP-IN"
    "DNS-OVER-TLS ENDPOINT НЕДОСТУПЕН"
    "АВТОМАТИКА ПРОВАЙДЕРА"
)
en_headings=(
    "GENERAL ACTIONS"
    "SSH DROP-IN IS NOT LOADED"
    "FOREIGN SSH PORT"
    "SEPARATE LINK DNS DOMAIN"
    "LATER RESOLVED DROP-IN"
    "DNS-OVER-TLS ENDPOINT UNAVAILABLE"
    "PROVIDER AUTOMATION"
)

for index in "${!ru_headings[@]}"; do
    gawk -v heading="${ru_headings[$index]}" '
        $0 == heading {
            found = 1
            getline
            adjacent = ($0 ~ /^- /)
        }
        END { exit (found && adjacent) ? 0 : 1 }
    ' "$RU_GUIDE" || test::fail "RU heading is missing or detached"
    gawk -v heading="${en_headings[$index]}" '
        $0 == heading {
            found = 1
            getline
            adjacent = ($0 ~ /^- /)
        }
        END { exit (found && adjacent) ? 0 : 1 }
    ' "$EN_GUIDE" || test::fail "EN heading is missing or detached"
done

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
