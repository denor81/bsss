#!/usr/bin/env bash
# tests/test_format_user_output.sh
# Тест для функции _format_user_output из modules/04-ssh-port.sh

# Подключаем тестируемый файл
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ТЕСТА
# ==========================================

# Вспомогательная функция для сравнения результатов
assertEquals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [ "$expected" != "$actual" ]; then
        echo "[X] $message [$expected]/[$actual]"
        return 1
    else
        echo "[V] $message [$expected]/[$actual]"
        return 0
    fi
}

# ==========================================
# ТЕСТЫ ФУНКЦИИ _format_user_output
# ==========================================

# Тест 1: проверка успешного форматирования вывода
test_format_user_output_success() {
    local output
    local exit_code

    # Захватываем вывод и код возврата (отключаем -e для захвата не 0)
    set +e
    output=$(_format_user_output 0 "SSH is running" "✓")
    exit_code=$?
    set -e

    # Проверяем вывод
    assertEquals "✓ SSH is running" "$output" "Вывод должен содержать символ и сообщение"

    # Проверяем код возврата
    assertEquals 0 "$exit_code" "Код возврата должен быть 0"
}

# Тест 2: проверка форматирования вывода с ошибкой
test_format_user_output_error() {
    local output
    local exit_code

    # Захватываем вывод и код возврата (отключаем -e для захвата не 0)
    set +e
    output=$(_format_user_output 1 "Connection failed" "✗")
    exit_code=$?
    set -e

    # Проверяем вывод
    assertEquals "✗ Connection failed" "$output" "Вывод должен содержать символ и сообщение"

    # Проверяем код возврата
    assertEquals 1 "$exit_code" "Код возврата должен быть 1"
}

# Тест 3: проверка с пустым сообщением
test_format_user_output_empty_message() {
    local output
    local exit_code

    # Захватываем вывод и код возврата (отключаем -e для захвата не 0)
    set +e
    output=$(_format_user_output 0 "" "?")
    exit_code=$?
    set -e

    # Проверяем вывод
    assertEquals "? " "$output" "Вывод должен содержать символ и пробел"

    # Проверяем код возврата
    assertEquals 0 "$exit_code" "Код возврата должен быть 0"
}

# Тест 4: проверка с пустым символом
test_format_user_output_empty_symbol() {
    local output
    local exit_code

    # Захватываем вывод и код возврата (отключаем -e для захвата не 0)
    set +e
    output=$(_format_user_output 1 "Warning" "")
    exit_code=$?
    set -e

    # Проверяем вывод
    assertEquals " Warning" "$output" "Вывод должен содержать пробел и сообщение"

    # Проверяем код возврата
    assertEquals 1 "$exit_code" "Код возврата должен быть 1"
}

# Тест 5: проверка с сообщением, содержащим пробелы
test_format_user_output_with_spaces() {
    local output
    local exit_code

    # Захватываем вывод и код возврата (отключаем -e для захвата не 0)
    set +e
    output=$(_format_user_output 0 "SSH port changed to 2222" "*")
    exit_code=$?
    set -e

    # Проверяем вывод
    assertEquals "* SSH port changed to 2222" "$output" "Вывод должен содержать символ и сообщение с пробелами"

    # Проверяем код возврата
    assertEquals 0 "$exit_code" "Код возврата должен быть 0"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Проверяем, запущен ли тест через раннер
    if [[ "${TEST_RUNNER_MODE:-}" == "1" ]]; then
        # Режим работы через раннер - выводим только в случае ошибок
        test_result=0
        
        # Запускаем тесты и захватываем вывод
        test_format_user_output_success || test_result=1
        test_format_user_output_error || test_result=1
        test_format_user_output_empty_message || test_result=1
        test_format_user_output_empty_symbol || test_result=1
        test_format_user_output_with_spaces || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _format_user_output из modules/04-ssh-port.sh"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_format_user_output_success
            test_format_user_output_error
            test_format_user_output_empty_message
            test_format_user_output_empty_symbol
            test_format_user_output_with_spaces
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _format_user_output из modules/04-ssh-port.sh"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_format_user_output_success
        test_format_user_output_error
        test_format_user_output_empty_message
        test_format_user_output_empty_symbol
        test_format_user_output_with_spaces
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi