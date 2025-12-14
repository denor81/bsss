#!/usr/bin/env bash
# test_format_eval_output.sh
# Тест для функции _format_eval_output из modules/04-ssh-port.sh

# Устанавливаем строгий режим выполнения
set -euo pipefail

# Подключаем тестируемый модуль
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

# Вспомогательная функция для декодирования base64
decode_base64() {
    local value="$1"
    if [[ -n "$value" ]]; then
        echo "$value" | base64 -d
    else
        echo ""
    fi
}

# Тест 1: Проверка с простыми значениями 1,2,3,4,5
test_format_eval_output_simple_values() {
    echo "Запуск теста 1: Проверка с простыми значениями 1,2,3,4,5"
    
    # Вызываем функцию с тестовыми значениями
    local output
    local return_code
    output=$(_format_eval_output 1 2 3 4 5)
    return_code=$?
    
    # Проверяем, что код возврата соответствует статусу
    if [[ $return_code -ne 1 ]]; then
        echo "ОШИБКА: Ожидался код возврата=1, получен код возврата=$return_code"
        return 1
    fi
    
    # Выполняем парсинг через eval
    eval "$output"
    
    # Декодируем только закодированные значения (message и symbol)
    local decoded_message
    local decoded_symbol
    decoded_message=$(decode_base64 "$message")
    decoded_symbol=$(decode_base64 "$symbol")
    
    # Выполняем сравнение с отправленными данными через ассерты
    # status должен быть 1
    if [[ "$status" -ne 1 ]]; then
        echo "ОШИБКА: Ожидался status=1, получен status=$status"
        return 1
    fi
    
    # decoded_message должен быть "2"
    if [[ "$decoded_message" != "2" ]]; then
        echo "ОШИБКА: Ожидалось decoded_message='2', получено decoded_message='$decoded_message'"
        return 1
    fi
    
    # decoded_symbol должен быть "3"
    if [[ "$decoded_symbol" != "3" ]]; then
        echo "ОШИБКА: Ожидался decoded_symbol='3', получен decoded_symbol='$decoded_symbol'"
        return 1
    fi
    
    # active_ssh_port должен быть "4"
    if [[ "$active_ssh_port" != "4" ]]; then
        echo "ОШИБКА: Ожидался active_ssh_port='4', получен active_ssh_port='$active_ssh_port'"
        return 1
    fi
    
    # config_files_ssh_port должен быть "5"
    if [[ "$config_files_ssh_port" != "5" ]]; then
        echo "ОШИБКА: Ожидался config_files_ssh_port='5', получен config_files_ssh_port='$config_files_ssh_port'"
        return 1
    fi
    
    echo "УСПЕХ: Тест 1 пройден"
    return 0
}

# Тест 2: Проверка с пустыми значениями
test_format_eval_output_empty_values() {
    echo "Запуск теста 2: Проверка с пустыми значениями"
    
    # Вызываем функцию с пустыми значениями
    local output
    local return_code
    output=$(_format_eval_output 0 "" "" "" "")
    return_code=$?
    
    # Проверяем, что код возврата соответствует статусу
    if [[ $return_code -ne 0 ]]; then
        echo "ОШИБКА: Ожидался код возврата=0, получен код возврата=$return_code"
        return 1
    fi
    
    # Выполняем парсинг через eval
    eval "$output"
    
    # Декодируем только закодированные значения (message и symbol)
    local decoded_message
    local decoded_symbol
    decoded_message=$(decode_base64 "$message")
    decoded_symbol=$(decode_base64 "$symbol")
    
    # Выполняем сравнение с отправленными данными через ассерты
    # status должен быть 0
    if [[ "$status" -ne 0 ]]; then
        echo "ОШИБКА: Ожидался status=0, получен status=$status"
        return 1
    fi
    
    # decoded_message должен быть пустой строкой
    if [[ "$decoded_message" != "" ]]; then
        echo "ОШИБКА: Ожидалось пустое decoded_message, получено decoded_message='$decoded_message'"
        return 1
    fi
    
    # decoded_symbol должен быть пустой строкой
    if [[ "$decoded_symbol" != "" ]]; then
        echo "ОШИБКА: Ожидался пустой decoded_symbol, получен decoded_symbol='$decoded_symbol'"
        return 1
    fi
    
    # active_ssh_port должен быть пустой строкой
    if [[ "$active_ssh_port" != "" ]]; then
        echo "ОШИБКА: Ожидался пустой active_ssh_port, получен active_ssh_port='$active_ssh_port'"
        return 1
    fi
    
    # config_files_ssh_port должен быть пустой строкой
    if [[ "$config_files_ssh_port" != "" ]]; then
        echo "ОШИБКА: Ожидался пустой config_files_ssh_port, получен config_files_ssh_port='$config_files_ssh_port'"
        return 1
    fi
    
    echo "УСПЕХ: Тест 2 пройден"
    return 0
}

# Тест 3: Проверка с особыми символами
test_format_eval_output_special_chars() {
    echo "Запуск теста 3: Проверка с особыми символами"
    
    # Вызываем функцию со специальными символами
    local output
    local return_code
    output=$(_format_eval_output 1 "Сообщение с пробелами и \$символами" "✓" "22,2222" "22,80,443")
    return_code=$?
    
    # Проверяем, что код возврата соответствует статусу
    if [[ $return_code -ne 1 ]]; then
        echo "ОШИБКА: Ожидался код возврата=1, получен код возврата=$return_code"
        return 1
    fi
    
    # Выполняем парсинг через eval
    eval "$output"
    
    # Декодируем только закодированные значения (message и symbol)
    local decoded_message
    local decoded_symbol
    decoded_message=$(decode_base64 "$message")
    decoded_symbol=$(decode_base64 "$symbol")
    
    # Выполняем сравнение с отправленными данными через ассерты
    # status должен быть 1
    if [[ "$status" -ne 1 ]]; then
        echo "ОШИБКА: Ожидался status=1, получен status=$status"
        return 1
    fi
    
    # decoded_message должен содержать специальное сообщение
    if [[ "$decoded_message" != "Сообщение с пробелами и \$символами" ]]; then
        echo "ОШИБКА: Ожидалось decoded_message='Сообщение с пробелами и \$символами', получено decoded_message='$decoded_message'"
        return 1
    fi
    
    # decoded_symbol должен быть "✓"
    if [[ "$decoded_symbol" != "✓" ]]; then
        echo "ОШИБКА: Ожидался decoded_symbol='✓', получен decoded_symbol='$decoded_symbol'"
        return 1
    fi
    
    # active_ssh_port должен быть "22,2222"
    if [[ "$active_ssh_port" != "22,2222" ]]; then
        echo "ОШИБКА: Ожидался active_ssh_port='22,2222', получен active_ssh_port='$active_ssh_port'"
        return 1
    fi
    
    # config_files_ssh_port должен быть "22,80,443"
    if [[ "$config_files_ssh_port" != "22,80,443" ]]; then
        echo "ОШИБКА: Ожидался config_files_ssh_port='22,80,443', получен config_files_ssh_port='$config_files_ssh_port'"
        return 1
    fi
    
    echo "УСПЕХ: Тест 3 пройден"
    return 0
}

# Тест 4: Проверка с коротким сообщением
test_format_eval_output_short_message() {
    echo "Запуск теста 4: Проверка с коротким сообщением"
    
    # Создаем короткое сообщение
    local short_message="Короткое сообщение"
    
    # Вызываем функцию с коротким сообщением
    local output
    local return_code
    output=$(_format_eval_output 0 "$short_message" "✓" "22" "22")
    return_code=$?
    
    # Проверяем, что код возврата соответствует статусу
    if [[ $return_code -ne 0 ]]; then
        echo "ОШИБКА: Ожидался код возврата=0, получен код возврата=$return_code"
        return 1
    fi
    
    # Выполняем парсинг через eval
    eval "$output"
    
    # Декодируем и проверяем message
    local decoded_message
    decoded_message=$(decode_base64 "$message")
    if [[ "$decoded_message" != "$short_message" ]]; then
        echo "ОШИБКА: Декодированное сообщение не соответствует исходному"
        echo "Ожидаемое: $short_message"
        echo "Полученное: $decoded_message"
        return 1
    fi
    
    echo "УСПЕХ: Тест 4 пройден"
    return 0
}

# Тест 5: Проверка с кавычками
test_format_eval_output_quotes() {
    echo "Запуск теста 5: Проверка с кавычками"
    
    # Создаем сообщение с кавычками
    local message_with_quotes="Сообщение с \"кавычками\" и 'апострофами'"
    
    # Вызываем функцию с сообщением, содержащим кавычки
    local output
    local return_code
    output=$(_format_eval_output 0 "$message_with_quotes" "!" "22" "22")
    return_code=$?
    
    # Проверяем, что код возврата соответствует статусу
    if [[ $return_code -ne 0 ]]; then
        echo "ОШИБКА: Ожидался код возврата=0, получен код возврата=$return_code"
        return 1
    fi
    
    # Выполняем парсинг через eval
    eval "$output"
    
    # Декодируем и проверяем message
    local decoded_message
    decoded_message=$(decode_base64 "$message")
    if [[ "$decoded_message" != "$message_with_quotes" ]]; then
        echo "ОШИБКА: Декодированное сообщение не соответствует исходному"
        echo "Ожидаемое: $message_with_quotes"
        echo "Полученное: $decoded_message"
        return 1
    fi
    
    echo "УСПЕХ: Тест 5 пройден"
    return 0
}

# Тест 6: Проверка с нулевым статусом
test_format_eval_output_zero_status() {
    echo "Запуск теста 6: Проверка с нулевым статусом"
    
    # Вызываем функцию с нулевым статусом
    local output
    local return_code
    output=$(_format_eval_output 0 "Сообщение об успехе" "✓" "" "22")
    return_code=$?
    
    # Проверяем, что код возврата соответствует статусу
    if [[ $return_code -ne 0 ]]; then
        echo "ОШИБКА: Ожидался код возврата=0, получен код возврата=$return_code"
        return 1
    fi
    
    # Выполняем парсинг через eval
    eval "$output"
    
    # Проверяем статус
    if [[ "$status" != "0" ]]; then
        echo "ОШИБКА: Ожидался status=0, получен status=$status"
        return 1
    fi
    
    echo "УСПЕХ: Тест 6 пройден"
    return 0
}

# Запускаем все тесты
main() {
    echo "Запуск тестов для функции _format_eval_output"
    
    local test_result=0
    
    # Запускаем тест 1
    if ! test_format_eval_output_simple_values; then
        test_result=1
    fi
    
    # Запускаем тест 2
    if ! test_format_eval_output_empty_values; then
        test_result=1
    fi
    
    # Запускаем тест 3
    if ! test_format_eval_output_special_chars; then
        test_result=1
    fi
    
    # Запускаем тест 4
    if ! test_format_eval_output_short_message; then
        test_result=1
    fi
    
    # Запускаем тест 5
    if ! test_format_eval_output_quotes; then
        test_result=1
    fi
    
    # Запускаем тест 6
    if ! test_format_eval_output_zero_status; then
        test_result=1
    fi
    
    if [[ $test_result -eq 0 ]]; then
        echo "Все тесты успешно пройдены"
    else
        echo "Некоторые тесты не пройдены"
    fi
    
    return $test_result
}

# Запускаем тесты, если файл запущен напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi