# Общие хелперы для тестов i18n

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly I18N_DIR="${PROJECT_ROOT}/lib/i18n"

# @type:        Source
# @description: Получает список языковых каталогов
# @stdin:       нет
# @stdout:      lang_code\0 (например: ru\0en\0)
# @exit_code:   0 - успех
i18n::get_languages() {
    find "$I18N_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\0' | sort -z
}

# @type:        Filter
# @description: Извлекает все ключи I18N_MESSAGES из файлов переводов языка
# @stdin:       lang_code\0
# @stdout:      lang_code|key\0
# @exit_code:   0 - успех
i18n::extract_keys() {
    local lang_code

    while IFS= read -r -d '' lang_code; do
        local lang_dir="${I18N_DIR}/${lang_code}"

        grep -rhE 'I18N_MESSAGES\["[^"]+"\]' "$lang_dir"/*.sh 2>/dev/null | \
            sed -E 's/.*I18N_MESSAGES\["([^"]+)"\].*/\1/' | \
            sort -u | \
            while IFS= read -r key; do
                printf '%s|%s\0' "$lang_code" "$key"
            done
    done
}

# @type:        Orchestrator
# @description: Проверяет наличие ключа перевода в указанных директориях
# @stdin:       lang_code|key\0
# @stdout:      key\0 (только для неиспользуемых ключей)
# @exit_code:   0 - успех
i18n::check_key_usage() {
    local key
    local count=0
    local search_dirs=(
        "${PROJECT_ROOT}/modules/helpers"
        "${PROJECT_ROOT}/modules"
        "${PROJECT_ROOT}/utils"
        "${PROJECT_ROOT}"
    )

    while IFS='|' read -r -d '' lang_code key; do
        local found=0

        for dir in "${search_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                count=$(grep -r --include="*.sh" --exclude-dir=i18n "$key" "$dir" 2>/dev/null | wc -l || true)
                if [[ $count -gt 0 ]]; then
                    found=1
                    break
                fi
            fi
        done

        if [[ $found -eq 0 ]]; then
            printf '%s|%s\0' "$lang_code" "$key"
        fi
    done
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

# @type:        Sink
# @description: Подсчитывает количество записей в NUL-разделенном потоке
# @stdin:       data\0
# @stdout:      количество записей
# @exit_code:   0 - успех
i18n::count_stream() {
    local count=0
    while IFS= read -r -d ''; do
        ((count++))
    done
    printf '%d\n' "$count"
}
