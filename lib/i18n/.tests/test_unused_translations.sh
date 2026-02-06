#!/usr/bin/env bash
# Проверяет неиспользуемые переводы в проекте

set -Eeuo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/helpers/test_helpers.sh"

# @type:        Orchestrator
# @description: Проверяет неиспользуемые переводы
# @stdin:       нет
# @stdout:      отчет о неиспользуемых переводах (если есть)
# @exit_code:   0 - все переводы используются
#               1 - найдены неиспользуемые переводы
i18n::test_unused_translations() {
    local result_count

    result_count=$(i18n::get_languages | i18n::extract_keys | i18n::check_key_usage | i18n::count_stream)

    if [[ $result_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# @type:        Orchestrator
# @description: Выводит отчет о неиспользуемых переводах
# @stdin:       нет
# @stdout:      отчет в stderr
# @exit_code:   0 - успех
i18n::report_unused_translations() {
    i18n::get_languages | i18n::extract_keys | i18n::check_key_usage | i18n::format_unused_message
}

main() {
    printf 'Показывает никогда не используемые переводы\n'
    local result_count

    result_count=$(i18n::get_languages | i18n::extract_keys | i18n::check_key_usage | i18n::count_stream)

    if [[ $result_count -eq 0 ]]; then
        printf 'All translations are used\n'
        return 0
    else
        i18n::report_unused_translations
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
