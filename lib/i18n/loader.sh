# @type:        Source
# @description: Определяет текущий язык из файла .lang
# @params:      нет
# @stdin:       нет
# @stdout:      lang_code (например: ru|en)
# @exit_code:   0 - успех
i18n::detect_language() {
    [[ -f "$LANG_FILE" ]] && cat "$LANG_FILE" 2>/dev/null || printf '%s' "$DEFAULT_LANG"
}

# @type:        Orchestrator
# @description: Загружает все файлы переводов для выбранного языка
# @params:      lang_code - код языка (ru|en|cn|...)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успех
#               1 - файл переводов не найден
i18n::load_translations() {
    local lang_code i18n_dir path

    read -r lang_code
    i18n_dir="${I18N_DIR}/${lang_code}"
    
    [[ ! -d "$i18n_dir" ]] && return 1
    
    declare -gA I18N_MESSAGES=() # Обнуляем массив
    while IFS= read -r -d '' path; do
        [[ -f "$path" ]] && source "$path"
    done < <(find "$i18n_dir" -type f -maxdepth 1 -name "*.sh" -print0)
}

# @type:        Orchestrator
# @description: Инициализирует систему i18n (обнаруживает и загружает)
# @params:      lang_code\0
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успех
#               $? - pipefail
i18n::load() {
    local lang_code="${1:-}"
    if [[ -n "$lang_code" ]]; then
        i18n::load_translations <<< "$(printf '%s' "$lang_code")"
    else
        i18n::load_translations <<< "$(i18n::detect_language)"
    fi
}

# @type:        Source
# @description: Переводчик сообщений по ключу
# @params:      message_key - Ключ сообщения в i18n системе
#               args - Аргументы для форматирования (опционально)
# @stdin:       нет
# @stdout:      Переведенное сообщение
# @exit_code:   0 - успех
#               1 - ключ не найден
_() {
    local key="$1"
    shift
    
    # if (( ${#I18N_MESSAGES[@]} == 0 )); then
    #     i18n::load "$DEFAULT_LANG"
    # fi

    if [[ -v I18N_MESSAGES["$key"] ]]; then
        printf "${I18N_MESSAGES["$key"]}" "$@"
    else
        printf '%s' "[$key] NOT TRANSLATED" >&2
    fi
}
