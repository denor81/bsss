#!/usr/bin/env bash
# Проверяет захардкоженные строки в printf/echo/print

set -Eeuo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/helpers/test_helpers.sh"

# @type:        Orchestrator
# @description: Проверяет наличие захардкоженных строк
# @stdin:       нет
# @stdout:      отчет о захардкоженных строках (если есть)
# @exit_code:   0 - нет захардкоженных строк
#               1 - найдены захардкоженные строки (предупреждение)
i18n::test_hardcoded_strings() {
    local result_count

    result_count=$(i18n::find_hardcoded_strings | i18n::count_stream)

    if [[ $result_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# @type:        Orchestrator
# @description: Выводит отчет о захардкоженных строках
# @stdin:       нет
# @stdout:      отчет в stderr
# @exit_code:   0 - успех
i18n::report_hardcoded_strings() {
    i18n::find_hardcoded_strings | i18n::format_hardcoded_message
}

main() {
    printf 'Проверяет захардкоженные строки, которые могут требовать локализации\n'
    local result_count

    result_count=$(i18n::find_hardcoded_strings | i18n::count_stream)

    if [[ $result_count -eq 0 ]]; then
        printf 'No hardcoded strings found that need translation\n'
        return 0
    else
        printf '\nWARNING: Found %d hardcoded string(s)\n\n' "$result_count" >&2
        printf 'These strings might need localization using the _() function.\n' >&2
        printf 'Review the output below and decide if each case requires translation.\n\n' >&2
        i18n::report_hardcoded_strings
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
