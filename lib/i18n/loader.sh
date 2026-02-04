#!/usr/bin/env bash
#
# @type:        Orchestrator
# @description: Автоматическая загрузка переводов на основе .lang файла
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успех
#               1 - файл .lang содержит недопустимый язык

# Объявление глобального массива для переводов
declare -gA I18N_MESSAGES

# @type:        Source
# @description: Определяет текущий язык из файла .lang
# @params:      нет
# @stdin:       нет
# @stdout:      lang_code (например: ru|en)
# @exit_code:   0 - успех
i18n::detect_language() {
    local lang_file="${PROJECT_ROOT}/.lang"
    local default_lang="ru"
    
    if [[ -f "$lang_file" ]]; then
        local detected_lang
        detected_lang=$(cat "$lang_file" 2>/dev/null | tr -d '[:space:]')
        
        # Валидация языка
        case "$detected_lang" in
            ru|en|cn|es|fr|de)
                echo "$detected_lang"
                return 0
                ;;
            *)
                echo "Invalid language in .lang file: $detected_lang" >&2
                echo "Supported languages: ru, en, cn, es, fr, de" >&2
                echo "Falling back to: $default_lang" >&2
                echo "$default_lang"
                return 0
                ;;
        esac
    else
        echo "$default_lang"
        return 0
    fi
}

# @type:        Orchestrator
# @description: Загружает все файлы переводов для выбранного языка
# @params:      lang_code - код языка (ru|en|cn|...)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успех
#               1 - файл переводов не найден
i18n::load_translations() {
    local lang_code="$1"
    local i18n_dir="${PROJECT_ROOT}/lib/i18n/${lang_code}"
    
    # Проверка существования директории языка
    if [[ ! -d "$i18n_dir" ]]; then
        echo "i18n directory not found: $i18n_dir" >&2
        return 1
    fi
    
    # Очистка предыдущих переводов (переобъявление ассоциативного массива)
    declare -gA I18N_MESSAGES=()
    
    # Загрузка всех .sh файлов из директории языка
    local translation_files
    mapfile -t translation_files < <(find "$i18n_dir" -maxdepth 1 -name "*.sh" -type f | sort)
    
    for file in "${translation_files[@]}"; do
        if [[ -r "$file" ]]; then
            . "$file"
        fi
    done
    
    # Логирование успешной загрузки
    # echo "Loaded i18n language: $lang_code from $i18n_dir" >&2
}

# @type:        Orchestrator
# @description: Инициализирует систему i18n (обнаруживает и загружает)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успех
#               1 - ошибка загрузки
i18n::init() {
    local lang
    lang=$(i18n::detect_language)
    
    if ! i18n::load_translations "$lang"; then
        echo "Failed to load translations for language: $lang" >&2
        return 1
    fi
    
    return 0
}
