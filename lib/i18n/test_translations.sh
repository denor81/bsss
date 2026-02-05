#!/usr/bin/env bash
# Проверяет синхронизацию файлов переводов

set -Eeuo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/test_helpers.sh"

# @type:        Orchestrator
# @description: Проверяет синхронизацию файлов переводов между языками
# @stdin:       нет
# @stdout:      отчет о несоответствиях (если есть)
# @exit_code:   0 - все переводы синхронизированы
#               1 - найдены несоответствия
i18n::test_translation_sync() {
    local langs
    local -A lang_keys_map
    local -A all_keys
    local result_count=0

    mapfile -t -d $'\0' langs < <(i18n::get_languages)

    if [[ ${#langs[@]} -lt 2 ]]; then
        printf 'Less than 2 language directories found\n' >&2
        return 0
    fi

    while IFS='|' read -r -d $'\0' lang key; do
        lang_keys_map["${lang}|${key}"]=1
        all_keys["$key"]=1
    done < <(i18n::get_languages | i18n::extract_keys)

    for key in "${!all_keys[@]}"; do
        for lang in "${langs[@]}"; do
            local lang_key="${lang}|${key}"
            if [[ -z "${lang_keys_map[$lang_key]+isset}" ]]; then
                printf 'Missing key [%s] in language [%s]\n' "$key" "$lang" >&2
                ((result_count++))
            fi
        done
    done

    [[ $result_count -eq 0 ]] && return 0 || return 1
}

main() {
    if i18n::test_translation_sync; then
        printf 'All translations are synchronized\n'
        return 0
    else
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
