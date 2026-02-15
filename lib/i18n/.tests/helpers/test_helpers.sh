# Общие хелперы для тестов i18n


readonly I18N_DIR="${PROJECT_ROOT}/lib/i18n"



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



# @type:        Source
# @description: Извлекает ключи переводов из исходного кода проекта
# @stdin:       нет
# @stdout:      key\0 (ключи переводов из кода)
# @exit_code:   0 - успех
i18n::extract_keys_from_code() {
    local search_dirs=(
        "${PROJECT_ROOT}/modules/helpers"
        "${PROJECT_ROOT}/modules"
        "${PROJECT_ROOT}/utils"
        "${PROJECT_ROOT}"
    )

    for dir in "${search_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Извлекаем ключи из метазаголовков (# MODULE_NAME: module.ufw.name)
            find "$dir" -type f -name "*.sh" \
                ! -path "*/docs/*" \
                ! -name "oneline-runner.sh" \
                -print0 2>/dev/null | \
                xargs -0 cat 2>/dev/null | \
                gawk '
                    {
                        if (match($0, /^#\s+MODULE_NAME:\s*(.+)$/, arr)) {
                            print arr[1]
                        }
                    }
                '

            # Извлекаем ключи из кода ($(_ "common.error_no_modules_available"))
            find "$dir" -type f -name "*.sh" \
                ! -path "*/docs/*" \
                ! -name "oneline-runner.sh" \
                -print0 2>/dev/null | \
                xargs -0 cat 2>/dev/null | \
                gawk '
                    {
                        while (match($0, /\$\(_[[:space:]]+"([^"]+)"/, arr)) {
                            key = arr[1]
                            # Проверяем, что ключ содержит точку (формат module.key) или это no_translate
                            if (key ~ /\./ || key == "no_translate") {
                                print key
                            }
                            # Продвигаемся дальше в строке
                            $0 = substr($0, RSTART + RLENGTH)
                        }
                    }
                '
        fi
    done | sort -u | while IFS= read -r key; do
        printf '%s\0' "$key"
    done
}


# @type:        Filter
# @description: Проверяет использование ключей через одиночное сканирование кода
# @stdin:       lang_code|key\0
# @stdout:      lang_code|key\0 (только неиспользуемые)
# @exit_code:   0 - успех
i18n::check_key_usage() {
    local -A used_keys_map
    local key lang_code
    
    while IFS= read -r -d '' key; do
        used_keys_map["$key"]=1
    done < <(i18n::extract_keys_from_code)
    
    while IFS='|' read -r -d '' lang_code key; do
        if [[ -z "${used_keys_map[$key]+isset}" ]]; then
            printf '%s|%s\0' "$lang_code" "$key"
        fi
    done
}





