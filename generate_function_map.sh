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
# @stdout:      function_name<:>type<:>description<:>file_path
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
                if (in_contract) {
                    func_name = $1
                    # Выводим в требуемом формате
                    print func_name "<:>" func_type "<:>" func_desc "<:>" file_path "\n"
                    in_contract = 0
                }
                next
            }
            
            # Альтернативный синтаксис функции: function name() (включая функции с двоеточиями)
            /^function[[:space:]]+[a-zA-Z_:][a-zA-Z0-9_:]*[[:space:]]*\(\)/ {
                if (in_contract) {
                    if (match($0, /function[[:space:]]+([a-zA-Z_:][a-zA-Z0-9_:]*)/, arr)) {
                        func_name = arr[1]
                        # Выводим в требуемом формате
                        print func_name "<:>" func_type "<:>" func_desc "<:>" file_path "\n"
                    }
                    in_contract = 0
                }
                next
            }
            
            # Если встречаем пустую строку или другой комментарий без контракта, сбрасываем флаг
            !/^#/ && in_contract {
                in_contract = 0
            }
        ' "$file_path"
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
    
    echo "Генерация карты функций..."
    
    # Генерируем карту функций и сохраняем в файл
    find_bash_files | extract_functions_from_file > "$output_file"
    
    echo "Карта функций сохранена в файл: $output_file"
    echo "Всего функций найдено: $(wc -l < "$output_file")"
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi