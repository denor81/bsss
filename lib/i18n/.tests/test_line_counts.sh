#!/usr/bin/env bash
# Проверяет количество строк в файлах локализаций

set -Eeuo pipefail

readonly PROJECT_ROOT=$(readlink -f "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/../../..")
readonly I18N_DIR="${PROJECT_ROOT}/lib/i18n"

main() {
    printf 'Checking line counts in localization files...\n'

    local count

    # Получаем количество уникальных значений строк
    count=$(find "$I18N_DIR" -maxdepth 1 -mindepth 1 -type d ! -path '*/.*' ! -name 'critical' | while IFS= read -r dir; do
        file="$dir/common.sh"
        if [ -f "$file" ]; then
            wc -l < "$file"
        fi
    done | awk '{print $1}' | sort -u | wc -l | tr -d '[:space:]')

    if [ "$count" -gt 1 ]; then
        printf 'ERROR: Line counts differ between localizations:\n' >&2
        find "$I18N_DIR" -maxdepth 1 -mindepth 1 -type d ! -path '*/.*' ! -name 'critical' | while IFS= read -r dir; do
            file="$dir/common.sh"
            if [ -f "$file" ]; then
                lines=$(wc -l < "$file" | awk '{print $1}')
                printf '%s: %s lines\n' "$(basename "$dir")" "$lines"
            fi
        done | sort -t: -k2 -n >&2
        return 1
    else
        printf 'All localization files have the same line count\n'
        return 0
    fi
}

main "$@"
