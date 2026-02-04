#!/usr/bin/env bash
#
# @type:        Orchestrator
# @description: Проверяет наличие неизвестных ключей переводов в коде
#               Находит ключи в коде проекта, которых нет в файлах переводов
# @params:      нет
# @stdin:       нет
# @stdout:      Список неизвестных ключей перевода
# @exit_code:   0 - проверка выполнена
#               1 - найдены неизвестные ключи

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
# @stdout:      список ключей (по одному на строку)
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
# @description: Извлекает все ключи из всех файлов переводов
# @params:      нет
# @stdin:       нет
# @stdout:      список ключей (по одному на строку)
# @exit_code:   0 - успех
extract_all_translation_keys() {
    local all_keys=""
    
    local languages
    languages=$(find "$I18N_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
    
    for lang in $languages; do
        local lang_keys
        lang_keys=$(find "${I18N_DIR}/${lang}" -maxdepth 1 -name "*.sh" -type f -print0 2>/dev/null | \
            while IFS= read -r -d '' file; do
                extract_translation_keys "$file"
            done)
        
        all_keys="${all_keys}${lang_keys}"$'\n'
    done
    
    echo "$all_keys" | sort -u | grep -v '^$'
}

# @type:        Source
# @description: Извлекает все используемые ключи из кода проекта
# @params:      нет
# @stdin:       нет
# @stdout:      список ключей с путем к файлу (формат: file:line key)
# @exit_code:   0 - успех
extract_used_keys_with_location() {
    local tmp_file
    tmp_file=$(mktemp)
    
    # Находим все bash файлы, исключая тесты перевода
    find "$PROJECT_ROOT" -name "*.sh" -type f ! -path "*/lib/i18n/*test*.sh" 2>/dev/null > "$tmp_file"
    
    # Находим все вызовы _$() в коде с номерами строк
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            grep -hn '\$(_ "' "$file" 2>/dev/null | \
                sed 's/^\([^:]*:[^:]*\):.*\$(_ "\([^"]*\)".*/\1 \2/'
        fi
    done < "$tmp_file"
    
    # Находим вызовы i18n::get() (будут помечены как устаревший стиль)
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            grep -hn '\$(i18n::get "' "$file" 2>/dev/null | \
                sed 's/^\([^:]*:[^:]*\):.*\$(i18n::get "\([^"]*\)".*/\1 \2 [DEPRECATED i18n::get]/'
        fi
    done < "$tmp_file"
    
    rm -f "$tmp_file"
}

# @type:        Orchestrator
# @description: Находит неизвестные ключи перевода в коде
# @params:      нет
# @stdin:       нет
# @stdout:      отчет о неизвестных ключах
# @exit_code:   0 - нет неизвестных ключей
#               1 - найдены неизвестные ключи
find_unknown_keys() {
    log_section "Проверка неизвестных ключей в коде"
    
    # Извлекаем все ключи из переводов
    local translation_keys
    translation_keys=$(extract_all_translation_keys)
    
    if [[ -z "$translation_keys" ]]; then
        log_error "Не найдены ключи переводов"
        return 1
    fi
    
    # Сохраняем ключи переводов во временный файл
    local tmp_translations
    tmp_translations=$(mktemp)
    echo "$translation_keys" > "$tmp_translations"
    
    # Извлекаем все используемые ключи с локацией
    local used_keys_with_location
    used_keys_with_location=$(extract_used_keys_with_location | sort -u)
    
    local unknown_count=0
    local deprecated_count=0
    local tmp_report
    tmp_report=$(mktemp)
    
    # Проверяем каждый ключ и сохраняем результат во временный файл
    echo "$used_keys_with_location" | while read -r location key deprecated; do
        if [[ -n "$deprecated" ]]; then
            # Устаревший стиль i18n::get
            echo "WARN:${location}: использование устаревшего стиля i18n::get вместо _$()" >> "$tmp_report"
        elif ! grep -q "^${key}$" "$tmp_translations"; then
            # Ключ не найден в переводах
            echo "ERROR:${location}: неизвестный ключ перевода '${key}'" >> "$tmp_report"
        fi
    done
    
    # Считаем и выводим результаты
    local error_count
    local warn_count
    error_count=$(grep -c "^ERROR:" "$tmp_report" 2>/dev/null || true)
    warn_count=$(grep -c "^WARN:" "$tmp_report" 2>/dev/null || true)
    
    # Выводим предупреждения
    grep "^WARN:" "$tmp_report" 2>/dev/null | sed 's/^WARN:/[!]/' >&2 || true
    
    # Выводим ошибки
    grep "^ERROR:" "$tmp_report" 2>/dev/null | sed 's/^ERROR:/[x]/' >&2 || true
    
    # Удаляем временный файл отчета
    rm -f "$tmp_report"
    
    unknown_count=$error_count
    deprecated_count=$warn_count
    
    # Удаляем временный файл
    rm -f "$tmp_translations"
    
    local total_used_keys
    total_used_keys=$(echo "$used_keys_with_location" | wc -l)
    
    log_info "Всего ключей в переводах: $(echo "$translation_keys" | wc -l)"
    log_info "Используемых ключей в коде: ${total_used_keys}"
    log_info "Неизвестных ключей в коде: ${unknown_count}"
    log_info "Устаревших вызовов i18n::get: ${deprecated_count}"
    
    # Возвращаем код ошибки (работаем через файл для выхода)
    if [[ $unknown_count -gt 0 ]] || [[ $deprecated_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# @type:        Orchestrator
# @description: Главная функция проверки неизвестных переводов
# @params:      нет
# @stdin:       нет
# @stdout:      полный отчет
# @exit_code:   0 - все проверки пройдены
#               1 - найдены неизвестные ключи
main() {
    log_section "I18n Unknown Translations Check"
    
    # Получаем список доступных языков
    local languages
    languages=$(find "$I18N_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
    
    if [[ -z "$languages" ]]; then
        log_error "Не найдены языковые каталоги в: $I18N_DIR"
        return 1
    fi
    
    log_info "Обнаруженные языки: $languages"
    
    # Проверяем неизвестные ключи
    local total_issues=0
    
    if find_unknown_keys; then
        :
    else
        total_issues=$?
    fi
    
    log_section "Summary"
    
    if [[ $total_issues -eq 0 ]]; then
        echo -e "${COLOR_GREEN}${SYMBOL_INFO} Все ключи в коде существуют в переводах!${COLOR_RESET}" >&2
        return 0
    else
        echo -e "${COLOR_RED}${SYMBOL_ERROR} Найдены проблемы: ${total_issues}${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}Добавьте недостающие переводы в соответствующие файлы${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}Замените i18n::get на _() для использования актуального стиля${COLOR_RESET}" >&2
        return 1
    fi
}

main "$@"
