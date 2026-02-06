# @type:        Filter
# @description: Проверка существования файла .lang
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - файл существует
#               1 - файл отсутствует
i18n::installer::check_lang_file() {
    [[ -f "${PROJECT_ROOT}/.lang" ]]
}

# @type:        Source
# @description: Парсер каталогов lib/i18n/ для получения списка языков
# @params:      нет
# @stdin:       нет
# @stdout:      lang_code\0 (NUL-разделенные коды языков в алфавитном порядке)
# @exit_code:   0 - успешно
#               $? - ошибка find
i18n::installer::discover_languages() {
    find "${PROJECT_ROOT}/lib/i18n" -mindepth 1 -maxdepth 1 -type d -not -path '*/.*' -not -name 'critical' -printf '%f\0' | sort -z
}

# @type:        Filter
# @description: Отображение меню выбора языка
# @params:      нет
# @stdin:       lang_code\0lang_code\0...
# @stdout:      selected_lang_code\0
# @exit_code:   0 - выбор сделан
#               1 - нет доступных языков (критическая ошибка)
i18n::installer::show_language_menu() {
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

    local max_id=${#lang_codes[@]}
    local selection
    read -r -d '' selection < <(io::ask_value "$(_ "no_translate" "Enter number / Введите номер")" "" "^[1-$max_id]$" "1-$max_id")

    printf '%s\0' "${lang_codes[$((selection - 1))]}"
}

# @type:        Sink
# @description: Запись/перезапись файла .lang из stdin
# @params:      нет
# @stdin:       lang_code\0
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка записи файла
i18n::installer::write_lang_file() {
    local lang_code
    IFS= read -r -d '' lang_code
    printf '%s' "$lang_code" > "${PROJECT_ROOT}/.lang"
}

# @type:        Orchestrator
# @description: Основная функция настройки языка при первом запуске
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - критическая ошибка
i18n::installer::lang_setup() {
    i18n::installer::discover_languages | i18n::installer::show_language_menu | i18n::installer::write_lang_file
    i18n::load
}

# @type:        Orchestrator
# @description: Установка языка из параметра
# @params:      нет
# @stdin:       нет
# @stdout:      lang_code\0
# @exit_code:   0 - успешно
#               1 - критическая ошибка
i18n::installer::lang_setup_from_param() {
    local lang="$1"

    if ! i18n::installer::is_valid_language "$lang"; then
        i18n::installer::lang_setup
    else
        printf '%s\0' "$1" | i18n::installer::write_lang_file
        i18n::load
    fi
}

i18n::installer::is_valid_language() {
    local target_lang="${1:-}"
    [[ -z "$target_lang" ]] && return 1

    # Прогоняем список через grep с флагами:
    # -z (входные данные разделены NUL)
    # -x (строгое совпадение всей строки)
    # -q (тихий режим, нам нужен только exit code)
    i18n::installer::discover_languages | grep -zxq "$target_lang"
}
