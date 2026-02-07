# @type:        Source
# @description: Парсер каталогов lib/i18n/ для получения списка языков
#               Исключены из поиска скрытые файлы [.*] и каталог [critical]
# @params:      нет
# @stdin:       нет
# @stdout:      lang_code\0 (NUL-разделенные коды языков в алфавитном порядке)
# @exit_code:   0 - успешно
#               $? - ошибка find
i18n::installer::discover_languages() {
    find "$I18N_DIR" -mindepth 1 -maxdepth 1 -type d -not -path '*/.*' -not -name 'critical' -printf '%f\0' | sort -z
}

# @type:        Filter
# @description: Отображение меню выбора языка
# @params:      нет
# @stdin:       lang_code\0lang_code\0...
# @stdout:      selected_lang_code\0
# @exit_code:   0 - выбор сделан
#               1 - нет доступных языков (критическая ошибка)
i18n::installer::select_language() {
    local -a lang_codes=()
    local i

    mapfile -d '' -t lang_codes

    if (( ${#lang_codes[@]} == 0 )); then
        printf '%s\n' "$(_ "no_translate" "No language directories found")" >&2
        return 1
    fi

    log_info "$(_ "no_translate" "Select language / Выберите язык")"
    for ((i = 0; i < ${#lang_codes[@]}; i++)); do
        log_info_simple_tab "$(_ "no_translate" "$((i + 1)).") ${lang_codes[$i]}"
    done
    local menu_exit="0"
    log_info_simple_tab "$(_ "common.exit" "$menu_exit")"

    local max_id=${#lang_codes[@]}
    local selection
    selection=$(io::ask_value "$(_ "no_translate" "Enter number / Введите номер")" "" "^[0-$max_id]$" "0-$max_id" "$menu_exit") || return 2
    # read -r -d '' selection < <(io::ask_value "$(_ "no_translate" "Enter number / Введите номер")" "" "^[0-$max_id]$" "0-$max_id" "$menu_exit")

    printf '%s\0' "${lang_codes[$((selection - 1))]}"
}

# @type:        Sink
# @description: Запись/перезапись файла .lang (код без переноса строки)
# @params:      lang_code [ru|en...]
# @stdin:       lang_code\0
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка записи файла
i18n::installer::write_lang_file() {
    local lang_code="${1:-}"
    [[ -z "$lang_code" ]] && read -r -d '' lang_code
    printf '%s' "$lang_code" > "$LANG_FILE"
}

# @type:        Orchestrator
# @description: Основная функция настройки языка при первом запуске
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - неизвестная ошибка
#               2|130 - отмена пользователя
i18n::installer::lang_setup() {
    # set -e завершает процесс, по этому лезем в код пайпа 1 и смотрим - была ли там отмена по коду 2
    i18n::installer::discover_languages | i18n::installer::select_language | i18n::installer::write_lang_file || {
        local rc_pipe=("${PIPESTATUS[@]}")
        local rc=${rc_pipe[1]}
        
        case $rc in
            2|130) return $rc ;; # Пробрасываем код 2/130
            *) return 1 ;; # Неизвестная ошибка
        esac
    }
}

# @type:        Orchestrator
# @description: Установка языка из параметра
# @params:      lang_code [ru|en...]
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - не корректный код языка в параметре
i18n::installer::lang_setup_from_param() {
    local lang_code="$1"

    if i18n::installer::is_valid_language "$lang_code"; then
        i18n::installer::write_lang_file "$lang_code"
    else
        log_error "$(_ "no_translate" "Invalid lang code from parameter -l [$lang_code]")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Определение ветки установки языка
# @params:      lang_code [ru|en...]
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
i18n::installer::dispatcher() { 
    local lang_code="$1"

    if [[ -n "$lang_code" ]]; then
        i18n::installer::lang_setup_from_param "$lang_code"
    elif [[ ! -f "$LANG_FILE" ]]; then
        i18n::installer::lang_setup
    else
        return # Код языка будет загружен из файла
    fi
}

# @type:        Filter
# @description: Существует ли каталог с языком
# @params:      lang_code [ru|en...]
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - язык существует
#               1 - не существует/параметр не передан
i18n::installer::is_valid_language() {
    local target_lang="${1:-}"
    [[ -z "$target_lang" ]] && return 1

    # Прогоняем список через grep с флагами:
    # -z (входные данные разделены NUL)
    # -x (строгое совпадение всей строки)
    # -q (тихий режим, нам нужен только exit code)
    i18n::installer::discover_languages | grep -zxq "$target_lang"
}
