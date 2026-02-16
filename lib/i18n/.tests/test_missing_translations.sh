#!/usr/bin/env bash
# Проверяет несуществующие переводы в коде проекта

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

# @type:        Source
# @description: Создает ассоциативный массив с ключами переводов из всех файлов переводов
# @stdin:       нет
# @stdout:      (заполняет глобальный ассоциативный массив, переданный по ссылке)
# @exit_code:   0 - успех
i18n::create_keys_map() {
    local -n keys_map_ref=$1

    while IFS='|' read -r -d '' lang_code key; do
        keys_map_ref["$key"]=1
    done < <(i18n::get_languages | i18n::extract_keys)
}


# @type:        Filter
# @description: Проверяет наличие ключа перевода в файлах переводов
# @stdin:       key\0
# @stdout:      key\0 (только для отсутствующих ключей)
# @exit_code:   0 - успех
i18n::check_key_exists() {
    local -A existing_keys_map

    i18n::create_keys_map existing_keys_map

    while IFS= read -r -d '' key; do
        if [[ -z "${existing_keys_map[$key]+isset}" ]]; then
            printf '%s\0' "$key"
        fi
    done
}

# @type:        Transformer
# @description: Форматирует сообщение о несуществующем переводе с местоположением
# @stdin:       key\0
# @stdout:      сообщение в stderr
# @exit_code:   0 - успех
i18n::format_missing_message_with_location() {
    while IFS= read -r -d '' key; do
        local location
        location=$(printf '%s\0' "$key" | i18n::find_key_location | tr '\0' '\n')
        if [[ -n "$location" ]]; then
            printf 'Missing translation key [%s] in translation files (found in: %s)\n' "$key" "$location" >&2
        else
            printf 'Missing translation key [%s] in translation files\n' "$key" >&2
        fi
    done
}

# @type:        Filter
# @description: Ищет местоположение ключа перевода в исходном коде
# @stdin:       key\0
# @stdout:      file_path:line_number\0 (первое место где найден ключ)
# @exit_code:   0 - успех
i18n::find_key_location() {
    local key
    while IFS= read -r -d '' key; do
        local search_dirs=(
            "${PROJECT_ROOT}/modules/helpers"
            "${PROJECT_ROOT}/modules"
            "${PROJECT_ROOT}/utils"
            "${PROJECT_ROOT}"
        )

        for dir in "${search_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                local result
                result=$(grep -rn --include="*.sh" --exclude-dir="docs" -F -- "$key" "$dir" 2>/dev/null | head -1)
                if [[ -n "$result" ]]; then
                    local file_path line_number
                    file_path=$(echo "$result" | cut -d: -f1)
                    line_number=$(echo "$result" | cut -d: -f2)
                    printf '%s:%s\0' "$file_path" "$line_number"
                    break
                fi
            fi
        done
    done
}

# @type:        Orchestrator
# @description: Выводит отчет о несуществующих переводах
# @stdin:       нет
# @stdout:      отчет в stderr
# @exit_code:   0 - успех
i18n::report_missing_translations() {
    i18n::extract_keys_from_code | i18n::check_key_exists | i18n::format_missing_message_with_location
}

main() {
    printf 'Показывает битые ссылки в коде проекта на переводы (либо этих переводов нет ни в одном языке i18n)\n'
    local result_count

    result_count=$(i18n::extract_keys_from_code | i18n::check_key_exists | i18n::count_stream)

    if [[ $result_count -eq 0 ]]; then
        printf 'All used translations exist\n'
    else
        i18n::report_missing_translations
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
