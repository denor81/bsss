# @type:        Source
# @description: Определяет текущий язык из файла .lang
# @params:      нет
# @stdin:       нет
# @stdout:      lang_code\n
# @exit_code:   0 - успех
#               1 - файл переводов не найден
i18n::detect_language() {
    if [[ -f "$LANG_FILE" ]]; then
        printf '%s\n' $(cat "$LANG_FILE" | tr -d '[:space:]')
        return
    fi

    log_error "$(_ "no_translate" "File [.lang] does not exists")"
    return 1
}

# @type:        Orchestrator
# @description: Загружает все файлы переводов для выбранного языка
# @stdin:       en\n
# @stdout:      нет
# @exit_code:   0 - успех
#               1 - файл переводов не найден
i18n::load_translations() {
    local lang_code
    read -r lang_code
    
    local path
    while IFS= read -r -d '' path; do
        [[ -f "$path" ]] && source "$path"
    done < <(find "${I18N_DIR}/${lang_code}" -type f -maxdepth 1 -name "*.sh" -print0)
}

# @type:        Orchestrator
# @description: Инициализирует систему i18n (обнаруживает и загружает)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успех
#               $? - pipefail
i18n::load() {
    # Загружаем в текущем процессе
    i18n::load_translations <<< "$(i18n::detect_language)"
}

# @type:        Source
# @description: Переводчик сообщений по ключу
# @params:      message_key - Ключ сообщения в i18n системе
#               args - Аргументы для форматирования (опционально)
# @stdin:       нет
# @stdout:      Переведенное сообщение
# @exit_code:   0 - успех
_() {
    local key="$1"
    shift
    
    if [[ -v I18N_MESSAGES["$key"] ]]; then
        local template="${I18N_MESSAGES["$key"]}"
        
        if [[ $# -eq 0 ]]; then
            printf '%s' "$template"
        else
            printf "$template" "$@"
        fi
        return
    fi
    
    # 4. Fallback для отсутствующего перевода
    printf '%s' "$(_ "no_translate" "[Key '$key' NOT TRANSLATED]" "$@")"
}

