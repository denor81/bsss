#!/usr/bin/env bash
# generate_function_map.sh
# Генерирует карту функций проекта с их контрактами
# Usage: ./generate_function_map.sh

set -Eeuo pipefail

# @type:        Source
# @description: Находит все bash файлы в проекте
# @params:      нет
# @stdin:       нет
# @stdout:      path\0 (0..N)
# @exit_code:   0 - всегда
find_bash_files() {
    find . -type f -name "*.sh" -print0 | sort -z
}

# @type:        Filter
# @description: Извлекает функции и их контракты из bash файла
# @params:      нет
# @stdin:       file_path\0
# @stdout:      function_name|type|description|file_path
# @exit_code:   0 - всегда
extract_functions_from_file() {
    local file_path
    while IFS= read -r -d '' file_path; do
        # Извлекаем все функции в файле
        awk -v file_path="$file_path" '
            # Флаг для отслеживания контракта функции
            BEGIN {
                in_contract = 0
                func_name = ""
                func_type = "UNKNOWN"
                func_desc = "UNKNOWN"
                ORS = ""
            }
            
            # Начало контракта функции
            /^# @type:/ {
                in_contract = 1
                func_type = "UNKNOWN"
                func_desc = "UNKNOWN"
                # Извлекаем тип
                if (match($0, /@type:[[:space:]]*(.+)/, arr)) {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", arr[1])
                    func_type = arr[1]
                }
                next
            }
            
            # Описание функции
            /^# @description:/ && in_contract {
                if (match($0, /@description:[[:space:]]*(.+)/, arr)) {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", arr[1])
                    func_desc = arr[1]
                }
                next
            }
            
            # Определение функции (включая функции с двоеточиями в имени)
            /^[a-zA-Z_:][a-zA-Z0-9_:]*[[:space:]]*\(\)/ {
                func_name = $1
                if (in_contract) {
                    print func_name "|" func_type "|" func_desc "|" file_path "\n"
                } else {
                    print func_name "|NO_CONTRACT|Функция без контракта|" file_path "\n"
                }
                in_contract = 0
                next
            }
            
            # Альтернативный синтаксис функции: function name() (включая функции с двоеточиями)
            /^function[[:space:]]+[a-zA-Z_:][a-zA-Z0-9_:]*[[:space:]]*\(\)/ {
                if (match($0, /function[[:space:]]+([a-zA-Z_:][a-zA-Z0-9_:]*)/, arr)) {
                    func_name = arr[1]
                    if (in_contract) {
                        print func_name "|" func_type "|" func_desc "|" file_path "\n"
                    } else {
                        print func_name "|NO_CONTRACT|Функция без контракта|" file_path "\n"
                    }
                }
                in_contract = 0
                next
            }
            
            # Если встречаем пустую строку или другой комментарий без контракта, сбрасываем флаг
            !/^#/ && in_contract {
                in_contract = 0
            }
        ' "$file_path"
    done
}

# @type:        Filter
# @description: Подсчитывает количество вызовов каждой функции
# @params:      нет
# @stdin:       function_name|type|description|file_path
# @stdout:      function_name|type|description|file_path|call_count
# @exit_code:   0 - всегда
count_function_calls() {
    local line
    local func_name
    local count
    
    while IFS= read -r line; do
        func_name=$(echo "$line" | cut -d'|' -f1 | sed 's/()$//')
        
        # Ищем вызовы функции в .sh файлах, исключая:
        # 1. Закомментированные строки (строки, начинающиеся с #)
        # 2. Определения функции (func_name() или function func_name())
        count=$(find . -type f -name "*.sh" -exec grep -h "\\b${func_name}\\b" {} + 2>/dev/null | \
                awk '!/^[[:space:]]*#/ && !/^([[:space:]]*)?'"${func_name}"'\(\)/ && !/^[[:space:]]*function[[:space:]]+'"${func_name}"'\(\)/' | \
                wc -l | tr -d ' ')
        
        echo "${line}|${count}"
    done
}

# @type:        Orchestrator
# @description: Основная точка входа для генерации карты функций
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    local output_file="function_map.txt"
    
    echo "Генерация карты функций с подсчетом вызовов..."
    
    # Создаем файл с заголовком
    echo "function_name|type|description|file_path|call_count" > "$output_file"
    
    # Генерируем карту функций с количеством вызовов
    find_bash_files | extract_functions_from_file | count_function_calls >> "$output_file"
    
    echo "Карта функций сохранена в файл: $output_file"
    echo "Всего функций найдено: $(($(wc -l < "$output_file") - 1))"
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi