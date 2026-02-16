#!/usr/bin/env bash
# Проверяет неиспользуемые переводы в проекте

set -Eeuo pipefail

readonly PROJECT_ROOT=$(readlink -f "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/../../..")

source "$(dirname "$0")/helpers/test_helpers.sh"

# @type:        Source
# @description: Получает список языковых каталогов
# @stdin:       нет
# @stdout:      lang_code\0 (например: ru\0en\0)
# @exit_code:   0 - успех
i18n::get_languages() {
    find "$I18N_DIR" -maxdepth 1 -mindepth 1 -type d ! -path '*/.*' -printf '%f\0' | sort -z
}



# @type:        Transformer
# @description: Форматирует сообщение о неиспользуемом переводе
# @stdin:       lang_code|key\0
# @stdout:      сообщение в stderr
# @exit_code:   0 - успех
i18n::format_unused_message() {
    while IFS='|' read -r -d '' lang_code key; do
        printf 'Unused translation key [%s] in language [%s]\n' "$key" "$lang_code" >&2
    done
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
    printf 'Показывает никогда не используемые переводы, на которые нет ссылок из проекта\n'
    local result_count

    result_count=$(i18n::get_languages | i18n::extract_keys | i18n::check_key_usage | i18n::count_stream)

    if [[ $result_count -eq 0 ]]; then
        printf 'All translations are used\n'
    else
        i18n::report_unused_translations
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
