#!/usr/bin/env bash
# Проверяет несуществующие переводы в коде проекта

set -Eeuo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/helpers/test_helpers.sh"

# @type:        Orchestrator
# @description: Проверяет несуществующие переводы в коде проекта
# @stdin:       нет
# @stdout:      отчет о несуществующих переводах (если есть)
# @exit_code:   0 - все используемые переводы существуют
#               1 - найдены несуществующие переводы
i18n::test_missing_translations() {
    local result_count

    result_count=$(i18n::extract_keys_from_code | i18n::check_key_exists | i18n::count_stream)

    if [[ $result_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# @type:        Orchestrator
# @description: Выводит отчет о несуществующих переводах
# @stdin:       нет
# @stdout:      отчет в stderr
# @exit_code:   0 - успех
i18n::report_missing_translations() {
    i18n::extract_keys_from_code | i18n::check_key_exists | i18n::format_missing_message
}

main() {
    printf 'Показывает битые ссылки в коде проекта на переводы\n'
    local result_count

    result_count=$(i18n::extract_keys_from_code | i18n::check_key_exists | i18n::count_stream)

    if [[ $result_count -eq 0 ]]; then
        printf 'All used translations exist\n'
        return 0
    else
        i18n::report_missing_translations
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
