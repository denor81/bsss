#!/usr/bin/env bash
#
# @type:        Orchestrator
# @description: Проверяет целостность переводов между всеми языками
#               Сообщает о недостающих ключах перевода
# @params:      нет
# @stdin:       нет
# @stdout:      Отчет о недостающих ключах
# @exit_code:   0 - проверка выполнена
#               1 - найдены недостающие ключи

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
# @description: Извлекает ключи i18n из указанного файла
# @params:      file_path - путь к файлу переводов
# @stdin:       нет
# @stdout:      список ключей (по одному на строку)
# @exit_code:   0 - успех
extract_keys() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    grep 'I18N_MESSAGES\[' "$file" | \
        sed 's/.*I18N_MESSAGES\["//;s/"\].*//' | \
        sort -u
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

# @type:        Orchestrator
# @description: Сравнивает ключи переводов между двумя языками для указанного файла
# @params:      file_name - имя файла переводов (например: common.sh)
#               lang1 - первый язык (например: ru)
#               lang2 - второй язык (например: en)
# @stdin:       нет
# @stdout:      отчет о различиях
# @exit_code:   0
compare_languages_for_file() {
    local file_name="$1"
    local lang1="$2"
    local lang2="$3"
    
    local file1="${I18N_DIR}/${lang1}/${file_name}"
    local file2="${I18N_DIR}/${lang2}/${file_name}"
    
    # Проверяем существование файлов
    if [[ ! -f "$file1" ]]; then
        log_warn "Файл не найден: ${lang1}/${file_name}"
        return 0
    fi
    
    if [[ ! -f "$file2" ]]; then
        log_warn "Файл не найден: ${lang2}/${file_name}"
        return 0
    fi
    
    # Извлекаем ключи
    local keys1 keys2
    keys1=$(extract_keys "$file1")
    keys2=$(extract_keys "$file2")
    
    # Сохраняем во временные файлы для сравнения
    local tmp1 tmp2
    tmp1=$(mktemp)
    tmp2=$(mktemp)
    
    echo "$keys1" > "$tmp1"
    echo "$keys2" > "$tmp2"
    
    # Находим ключи в lang1 но не в lang2
    local missing_in_2
    missing_in_2=$(comm -23 "$tmp1" "$tmp2" 2>/dev/null || true)
    
    # Находим ключи в lang2 но не в lang1
    local missing_in_1
    missing_in_1=$(comm -13 "$tmp1" "$tmp2" 2>/dev/null || true)
    
    # Удаляем временные файлы
    rm -f "$tmp1" "$tmp2"
    
    local issue_count=0
    
    if [[ -n "$missing_in_2" ]]; then
        log_warn "${file_name}: ключи в ${lang1} но НЕ в ${lang2}:"
        echo "$missing_in_2" | while read -r key; do
            echo "    - $key" >&2
        done
        issue_count=$(echo "$missing_in_2" | grep -c '^' || true)
    fi
    
    if [[ -n "$missing_in_1" ]]; then
        log_warn "${file_name}: ключи в ${lang2} но НЕ в ${lang1}:"
        echo "$missing_in_1" | while read -r key; do
            echo "    - $key" >&2
        done
        local count
        count=$(echo "$missing_in_1" | grep -c '^' || true)
        ((issue_count += count))
    fi
    
    return "$issue_count"
}

# @type:        Orchestrator
# @description: Проверяет все файлы переводов для пары языков
# @params:      lang1 - первый язык
#               lang2 - второй язык
# @stdin:       нет
# @stdout:      отчет о различиях
# @exit_code:   0 - нет различий
#               1 - найдены различия
check_language_pair() {
    local lang1="$1"
    local lang2="$2"
    
    log_section "Сравнение: ${lang1} <-> ${lang2}"
    
    local total_issues=0
    local file_issues
    
    # Получаем список файлов из первого языка
    local files
    files=$(find "${I18N_DIR}/${lang1}" -maxdepth 1 -name "*.sh" -type f -exec basename {} \; 2>/dev/null | sort || true)
    
    if [[ -z "$files" ]]; then
        log_error "Не найдены файлы переводов для языка: ${lang1}"
        return 1
    fi
    
    for file in $files; do
        compare_languages_for_file "$file" "$lang1" "$lang2" >/dev/null
        file_issues=$?
        ((total_issues += file_issues))
    done
    
    # Проверяем файлы во втором языке, которых нет в первом
    local files2
    files2=$(find "${I18N_DIR}/${lang2}" -maxdepth 1 -name "*.sh" -type f -exec basename {} \; 2>/dev/null | sort || true)
    
    for file in $files2; do
        if [[ -n "${files//"$file"/}" ]]; then
            # Файл есть во втором языке, но нет в первом
            compare_languages_for_file "$file" "$lang1" "$lang2" >/dev/null
            file_issues=$?
            ((total_issues += file_issues))
        fi
    done
    
    # Проверяем файлы во втором языке, которых нет в первом
    local files2
    files2=$(find "${I18N_DIR}/${lang2}" -maxdepth 1 -name "*.sh" -type f -exec basename {} \; 2>/dev/null | sort || true)
    
    for file in $files2; do
        if [[ -n "${files//"$file"/}" ]]; then
            # Файл есть во втором языке, но нет в первом
            compare_languages_for_file "$file" "$lang1" "$lang2" 2>/dev/null || true
            file_issues=$?
            ((total_issues += file_issues))
        fi
    done
    
    if [[ $total_issues -eq 0 ]]; then
        log_info "Нет различий между ${lang1} и ${lang2}"
    else
        log_info "Найдено различий: ${total_issues}"
    fi
    
    return "$total_issues"
}

# @type:        Orchestrator
# @description: Главная функция проверки переводов
# @params:      нет
# @stdin:       нет
# @stdout:      полный отчет
# @exit_code:   0 - все проверки пройдены
#               1 - найдены различия
main() {
    log_section "I18n Translation Integrity Check"
    
    local total_issues=0
    local pair_issues
    
    # Получаем список доступных языков
    local languages
    languages=$(find "$I18N_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
    
    if [[ -z "$languages" ]]; then
        log_error "Не найдены языковые каталоги в: $I18N_DIR"
        return 1
    fi
    
    log_info "Обнаруженные языки: $languages"
    
    # Сравниваем каждый язык с каждым (попарно)
    local lang_list
    mapfile -t lang_list <<< "$(echo "$languages")"
    
    local i j
    local lang1 lang2
    
    for ((i=0; i<${#lang_list[@]}; i++)); do
        for ((j=i+1; j<${#lang_list[@]}; j++)); do
            lang1="${lang_list[$i]}"
            lang2="${lang_list[$j]}"
            
            if check_language_pair "$lang1" "$lang2"; then
                :
            else
                pair_issues=$?
                ((total_issues += pair_issues))
            fi
        done
    done
    
    log_section "Summary"
    
    if [[ $total_issues -eq 0 ]]; then
        echo -e "${COLOR_GREEN}${SYMBOL_INFO} Все переводы синхронизированы!${COLOR_RESET}" >&2
        return 0
    else
        echo -e "${COLOR_RED}${SYMBOL_ERROR} Всего различий: ${total_issues}${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}Добавьте недостающие переводы в соответствующие файлы${COLOR_RESET}" >&2
        return 1
    fi
}

main "$@"
