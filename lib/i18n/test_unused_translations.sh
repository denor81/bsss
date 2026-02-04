#!/usr/bin/env bash
#
# @type:        Orchestrator
# @description: Проверяет наличие неиспользуемых переводов
#               Находит ключи в файлах переводов, которые не используются в коде проекта
# @params:      нет
# @stdin:       нет
# @stdout:      Список неиспользуемых ключей перевода
# @exit_code:   0 - проверка выполнена
#               1 - найдены неиспользуемые ключи

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/../.."
readonly I18N_DIR="${PROJECT_ROOT}/lib/i18n"

readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_WARN="[!]"
readonly SYMBOL_ERROR="[x]"

# Цвета
readonly COLOR_RED='\e[31m'
readonly COLOR_YELLOW='\e[33m'
readonly COLOR_GREEN='\e[32m'
readonly COLOR_RESET='\e[0m'

# @type:        Source
# @description: Извлекает все функции логгера из logging.sh
#               Парсит файл автоматически для получения актуального списка функций
# @params:      нет
# @stdin:       нет
# @stdout:      список функций через | для regex (log_info|log_error|...)
# @exit_code:   0
get_logger_functions_pattern() {
    grep -E '^.+\(\) \{' "${PROJECT_ROOT}/lib/logging.sh" 2>/dev/null | \
        sed 's/.*\([a-z_:_]*\)(.*/\1/' | \
        tr '\n' '|' | \
        sed 's/|$//'
}

# @type:        Source
# @description: Извлекает все функции io::* из user_confirmation.sh
#               Парсит файл автоматически для получения актуального списка функций
# @params:      нет
# @stdin:       нет
# @stdout:      список функций через | для regex (ask_value|confirm_action)
# @exit_code:   0
get_io_functions_pattern() {
    grep -E 'io::.+\(\) \{' "${PROJECT_ROOT}/lib/user_confirmation.sh" 2>/dev/null | \
        sed 's/.*io::\([a-z_]*\)(.*/\1/' | \
        sort -u | \
        tr '\n' '|' | \
        sed 's/|$//'
}

# @type:        Orchestrator
# @description: Инициализирует паттерны функций
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0
init_function_patterns() {
    readonly LOGGER_FUNCTIONS_PATTERN=$(get_logger_functions_pattern)
    readonly IO_FUNCTIONS_PATTERN=$(get_io_functions_pattern)
}

# @type:        Sink
# @description: Выводит информационное сообщение
# @params:      message - сообщение
# @stdin:       нет
# @stdout:      сообщение в stderr
# @exit_code:   0
log_info() {
    echo -e "${SYMBOL_INFO} $*" >&2
}

# @type:        Sink
# @description: Выводит предупреждение
# @params:      message - сообщение
# @stdin:       нет
# @stdout:      сообщение в stderr
# @exit_code:   0
log_warn() {
    echo -e "${COLOR_YELLOW}${SYMBOL_WARN} $*${COLOR_RESET}" >&2
}

# @type:        Sink
# @description: Выводит ошибку
# @params:      message - сообщение
# @stdin:       нет
# @stdout:      сообщение в stderr
# @exit_code:   0
log_error() {
    echo -e "${COLOR_RED}${SYMBOL_ERROR} $*${COLOR_RESET}" >&2
}

# @type:        Sink
# @description: Выводит заголовок раздела
# @params:      title - заголовок
# @stdin:       нет
# @stdout:      разделитель и заголовок
# @exit_code:   0
log_section() {
    echo "" >&2
    echo "========================================" >&2
    echo "$1" >&2
    echo "========================================" >&2
}

# @type:        Source
# @description: Извлекает ключи i18n из указанного файла переводов
# @params:      file_path - путь к файлу переводов
# @stdin:       нет
# @stdout:      список ключей (по одному на строке)
# @exit_code:   0 - успех
extract_translation_keys() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    grep 'I18N_MESSAGES\[' "$file" | \
        sed 's/.*I18N_MESSAGES\["//;s/"\].*//' | \
        sort -u
}

# @type:        Source
# @description: Извлекает ключи i18n из всех файлов переводов указанного языка
# @params:      lang - язык (например: ru)
# @stdin:       нет
# @stdout:      список ключей (по одному на строку)
# @exit_code:   0 - успех
extract_all_keys_from_lang() {
    local lang="$1"
    local lang_dir="${I18N_DIR}/${lang}"
    
    if [[ ! -d "$lang_dir" ]]; then
        return 0
    fi
    
    find "$lang_dir" -maxdepth 1 -name "*.sh" -type f -print0 | \
        while IFS= read -r -d '' file; do
            extract_translation_keys "$file"
        done | sort -u
}

# @type:        Source
# @description: Извлекает все используемые ключи из кода проекта
#               Использует простые устойчивые паттерны для обнаружения
# @params:      нет
# @stdin:       нет
# @stdout:      список ключей (по одному на строке)
# @exit_code:   0 - успех
extract_used_keys() {
    local exclude_dirs="--exclude-dir=${I18N_DIR} --exclude-dir=.git"

    grep -rh '$(_ "' "$PROJECT_ROOT" $exclude_dirs --include="*.sh" 2>/dev/null | \
        grep -oP '\$\(_\s+"\K[^"]+' | \
        sort -u
}

# @type:        Source
# @description: Извлекает ключи из вызовов log_* функций без _$()
#               Ищет простым паттерном: имя_функции "ключ"
#               Использует динамический паттерн из logging.sh
# @params:      нет
# @stdin:       нет
# @stdout:      список ключей (по одному на строке)
# @exit_code:   0 - успех
extract_log_keys() {
    local exclude_dirs="--exclude-dir=${I18N_DIR} --exclude-dir=.git"
    local pattern="$LOGGER_FUNCTIONS_PATTERN"

    grep -rhE "(${pattern}) \"" "$PROJECT_ROOT" $exclude_dirs --include="*.sh" 2>/dev/null | \
        sed -E "s/.*(${pattern}) \"([^\"]+)\".*/\2/" | \
        grep -vE '^\$' | \
        sort -u
}

# @type:        Source
# @description: Извлекает ключи из вызовов io::* функций
#               Ищет простым паттерном: io::функция "ключ"
# @params:      нет
# @stdin:       нет
# @stdout:      список ключей (по одному на строке)
# @exit_code:   0 - успех
extract_io_keys() {
    local exclude_dirs="--exclude-dir=${I18N_DIR} --exclude-dir=.git"

    grep -rhE 'io::(confirm_action|ask_value) "' "$PROJECT_ROOT" $exclude_dirs --include="*.sh" 2>/dev/null | \
        sed -E 's/.*io::(confirm_action|ask_value) "([^"]+)".*/\2/' | \
        grep -vE '^\$' | \
        sort -u
}

# @type:        Source
# @description: Извлекает ключи из вызовов log_* функций без _$()
# @params:      нет
# @stdin:       нет
# @stdout:      список ключей (по одному на строке)
# @exit_code:   0 - успех
extract_log_keys() {
    local exclude_dirs="--exclude-dir=${I18N_DIR} --exclude-dir=.git"
    
    # Находим вызовы log_info "key", log_error "key" и т.д.
    grep -rhE '(log_info|log_error|log_warn|log_success|log_debug|log_bold_info|log_attention|log_actual_info|log_info_simple_tab) "[^$]' "$PROJECT_ROOT" $exclude_dirs --include="*.sh" 2>/dev/null | \
        sed -E 's/.*(log_info|log_error|log_warn|log_success|log_debug|log_bold_info|log_attention|log_actual_info|log_info_simple_tab) "([^"]+)".*/\2/' | \
        grep -vE '^\$' | \
        sort -u
}

# @type:        Source
# @description: Извлекает ключи из вызовов io::* функций
# @params:      нет
# @stdin:       нет
# @stdout:      список ключей (по одному на строке)
# @exit_code:   0 - успех
extract_io_keys() {
    local exclude_dirs="--exclude-dir=${I18N_DIR} --exclude-dir=.git"
    
    # Находим вызовы io::confirm_action, io::ask_value с _$()
    # Эти уже будут найдены в extract_used_keys, поэтому здесь только дополнительно
    
    # Находим вызовы io::confirm_action/i18n::get без _$()
    grep -rhE '(io::confirm_action|io::ask_value) "[^$]' "$PROJECT_ROOT" $exclude_dirs --include="*.sh" 2>/dev/null | \
        sed -E 's/.*(io::confirm_action|io::ask_value) "([^"]+)".*/\2/' | \
        grep -vE '^\$' | \
        sort -u
}

# @type:        Orchestrator
# @description: Находит неиспользуемые ключи переводов
# @params:      lang - язык для проверки
# @stdin:       нет
# @stdout:      отчет о неиспользуемых ключах
# @exit_code:   0 - нет неиспользуемых ключей
#               1 - найдены неиспользуемые ключи
find_unused_keys() {
    local lang="$1"
    
    log_section "Проверка языка: ${lang}"
    
    # Извлекаем все ключи из переводов
    local translation_keys
    translation_keys=$(extract_all_keys_from_lang "$lang")
    
    if [[ -z "$translation_keys" ]]; then
        log_warn "Не найдены ключи переводов для языка: ${lang}"
        return 0
    fi
    
    # Извлекаем все используемые ключи из кода
    local used_keys
    used_keys=$(cat <(extract_used_keys) <(extract_log_keys) <(extract_io_keys) | sort -u)
    
    if [[ -z "$used_keys" ]]; then
        log_warn "Не найдено используемых ключей в коде"
        return 0
    fi
    
    # Сохраняем во временные файлы для сравнения
    local tmp_translations tmp_used
    tmp_translations=$(mktemp)
    tmp_used=$(mktemp)
    
    echo "$translation_keys" > "$tmp_translations"
    echo "$used_keys" > "$tmp_used"
    
    # Находим ключи в переводах, но не в коде
    local unused_keys
    unused_keys=$(comm -23 "$tmp_translations" "$tmp_used" 2>/dev/null || true)
    
    # Удаляем временные файлы
    rm -f "$tmp_translations" "$tmp_used"
    
    local unused_count=0
    
    if [[ -n "$unused_keys" ]]; then
        log_warn "Неиспользуемые ключи в переводах (${lang}):"
        echo "$unused_keys" | while read -r key; do
            echo "    - $key" >&2
            ((unused_count++)) || true
        done
        unused_count=$(echo "$unused_keys" | grep -c '^' || true)
    fi
    
    log_info "Всего ключей в переводах: $(echo "$translation_keys" | wc -l)"
    log_info "Используемых ключей в коде: $(echo "$used_keys" | wc -l)"
    log_info "Неиспользуемых ключей: ${unused_count}"
    
    if [[ $unused_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# @type:        Orchestrator
# @description: Главная функция проверки неиспользуемых переводов
# @params:      нет
# @stdin:       нет
# @stdout:      полный отчет
# @exit_code:   0 - все проверки пройдены
#               1 - найдены неиспользуемые ключи
main() {
    init_function_patterns
    log_section "I18n Unused Translations Check"
    
    local total_unused=0
    local lang_issues
    
    # Получаем список доступных языков
    local languages
    languages=$(find "$I18N_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
    
    if [[ -z "$languages" ]]; then
        log_error "Не найдены языковые каталоги в: $I18N_DIR"
        return 1
    fi
    
    log_info "Обнаруженные языки: $languages"
    
    # Проверяем каждый язык
    local lang
    for lang in $languages; do
        if find_unused_keys "$lang"; then
            :
        else
            lang_issues=$?
            ((total_unused += lang_issues))
        fi
    done
    
    log_section "Summary"
    
    if [[ $total_unused -eq 0 ]]; then
        echo -e "${COLOR_GREEN}${SYMBOL_INFO} Все переводы используются!${COLOR_RESET}" >&2
        return 0
    else
        echo -e "${COLOR_YELLOW}${SYMBOL_WARN} Всего неиспользуемых ключей: ${total_unused}${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}Рекомендуется удалить неиспользуемые ключи из файлов переводов${COLOR_RESET}" >&2
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
