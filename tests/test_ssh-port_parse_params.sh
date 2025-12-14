#!/usr/bin/env bash
# tests/test_parse_params_ssh_port.sh
# Тест для функции _parse_params из modules/04-ssh-port.sh

# Подключаем тестируемый файл
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
# (переменные для тестируемой функции определяются в каждом тесте локально)

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ТЕСТА
# ==========================================
# Глобальные переменные для отслеживания вызовов log_info и log_error
LOG_INFO_CALLS=0
LOG_INFO_MESSAGES=()
LOG_ERROR_CALLS=0
LOG_ERROR_MESSAGES=()

log_info() {
    LOG_INFO_CALLS=$((LOG_INFO_CALLS + 1))
    LOG_INFO_MESSAGES+=("$*")
}

log_error() {
    LOG_ERROR_CALLS=$((LOG_ERROR_CALLS + 1))
    LOG_ERROR_MESSAGES+=("$*")
}

reset_log_info() {
    LOG_INFO_CALLS=0
    LOG_INFO_MESSAGES=()
}

reset_log_error() {
    LOG_ERROR_CALLS=0
    LOG_ERROR_MESSAGES=()
}

assert_log_info_called() {
    local expected_calls="$1"
    local message="$2"
    
    if [ "$LOG_INFO_CALLS" -eq "$expected_calls" ]; then
        echo "[V] $message (вызовов: $LOG_INFO_CALLS)"
        return 0
    else
        echo "[X] $message (ожидалось: $expected_calls, получено: $LOG_INFO_CALLS)"
        return 1
    fi
}

assert_log_info_contains() {
    local pattern="$1"
    local message="$2"
    local found=0
    
    for msg in "${LOG_INFO_MESSAGES[@]}"; do
        if [[ "$msg" == *"$pattern"* ]]; then
            found=1
            break
        fi
    done
    
    if [ $found -eq 1 ]; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message (не найдено: '$pattern')"
        return 1
    fi
}

assert_log_error_called() {
    local expected_calls="$1"
    local message="$2"
    
    if [ "$LOG_ERROR_CALLS" -eq "$expected_calls" ]; then
        echo "[V] $message (вызовов: $LOG_ERROR_CALLS)"
        return 0
    else
        echo "[X] $message (ожидалось: $expected_calls, получено: $LOG_ERROR_CALLS)"
        return 1
    fi
}

assert_log_error_contains() {
    local pattern="$1"
    local message="$2"
    local found=0
    
    for msg in "${LOG_ERROR_MESSAGES[@]}"; do
        if [[ "$msg" == *"$pattern"* ]]; then
            found=1
            break
        fi
    done
    
    if [ $found -eq 1 ]; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message (не найдено: '$pattern')"
        return 1
    fi
}

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
# ТЕСТЫ ФУНКЦИИ _parse_params
# ==========================================

# Тест 1: проверка парсинга параметра -r (RUN_FLAG)
test_parse_params_run_flag() {
    # Сбрасываем флаги перед тестом
    RUN_FLAG=0
    reset_log_info
    reset_log_error
    
    # Вызываем тестируемую функцию с параметром -r
    _parse_params "r" "-r"
    
    # Проверяем результат
    assertEquals 1 $RUN_FLAG "RUN_FLAG должен быть установлен в 1"
    assert_log_info_called 0 "log_info не должен вызываться при валидном параметре -r"
    assert_log_error_called 0 "log_error не должен вызываться при валидном параметре -r"
}

# Тест 2: проверка работы без параметров
test_parse_params_no_params() {
    # Сбрасываем флаги перед тестом
    RUN_FLAG=0
    reset_log_info
    reset_log_error
    
    # Вызываем тестируемую функцию без параметров
    _parse_params "r"
    
    # Проверяем результат (флаг не должен измениться)
    assertEquals 0 $RUN_FLAG "RUN_FLAG должен остаться 0"
    assert_log_info_called 0 "log_info не должен вызываться без параметров"
    assert_log_error_called 0 "log_error не должен вызываться без параметров"
}

# Тест 3: проверка некорректного параметра
test_parse_params_invalid_param() {
    # Сбрасываем флаги перед тестом
    RUN_FLAG=0
    reset_log_info
    reset_log_error
    
    # Вызываем тестируемую функцию с некорректным параметром -x
    _parse_params "r" "-x"
    
    # Проверяем результат (флаг не должен измениться)
    assertEquals 0 $RUN_FLAG "RUN_FLAG должен остаться 0"
    assert_log_info_called 0 "log_info не должен вызываться при невалидном параметре"
    assert_log_error_called 1 "log_error должен быть вызван 1 раз при невалидном параметре"
    assert_log_error_contains "Некорректный параметр" "Сообщение должно содержать текст об ошибке"
    assert_log_error_contains "-x" "Сообщение должно содержать некорректный параметр"
}

# Тест 4: проверка параметра, требующего значение
test_parse_params_missing_value() {
    # Сбрасываем флаги перед тестом
    RUN_FLAG=0
    reset_log_info
    reset_log_error
    
    # Вызываем тестируемую функцию с параметром, требующим значение
    # Теперь r требует значение (: после r)
    _parse_params "r:" "-r"
    
    # Проверяем результат
    assertEquals 0 $RUN_FLAG "RUN_FLAG не должен устанавливаться без значения"
    assert_log_info_called 0 "log_info не должен вызываться при отсутствии значения"
    assert_log_error_called 1 "log_error должен быть вызван при отсутствии значения"
    assert_log_error_contains "требует значение" "Сообщение должно указывать на отсутствие значения"
    assert_log_error_contains "-r" "Сообщение должно содержать проблемный параметр"
}

# Тест 5: проверка работы с пользовательским набором параметров
test_parse_params_custom_allowed_params() {
    # Сбрасываем флаги перед тестом
    RUN_FLAG=0
    reset_log_info
    reset_log_error
    
    # Вызываем тестируемую функцию с пользовательским набором параметров
    # Используем -x, который не входит в список разрешенных abc
    _parse_params "abc" "-x"
    
    # Проверяем результат (флаг не должен измениться, т.к. -x не в списке разрешенных)
    assertEquals 0 $RUN_FLAG "RUN_FLAG должен остаться 0"
    assert_log_info_called 0 "log_info не должен вызываться"
    assert_log_error_called 1 "log_error должен быть вызван при невалидном параметре"
    assert_log_error_contains "Некорректный параметр" "Сообщение должно содержать текст об ошибке"
    assert_log_error_contains "-x" "Сообщение должно содержать некорректный параметр"
}

# Тест 6: проверка работы с параметром по умолчанию
test_parse_params_default_allowed_params() {
    # Сбрасываем флаги перед тестом
    RUN_FLAG=0
    reset_log_info
    reset_log_error
    
    # Вызываем тестируемую функцию без указания разрешенных параметров
    # Должен использоваться ALLOWED_PARAMS по умолчанию
    _parse_params "" "-r"
    
    # Проверяем результат (флаг должен измениться, т.к. -r в ALLOWED_PARAMS по умолчанию)
    assertEquals 1 $RUN_FLAG "RUN_FLAG должен быть установлен в 1"
    assert_log_info_called 0 "log_info не должен вызываться при валидном параметре -r"
    assert_log_error_called 0 "log_error не должен вызываться при валидном параметре -r"
}

# Тест 7: проверка работы с несколькими параметрами
test_parse_params_multiple_params() {
    # Сбрасываем флаги перед тестом
    RUN_FLAG=0
    reset_log_info
    reset_log_error
    
    # Вызываем тестируемую функцию с несколькими параметрами (один валидный, один нет)
    _parse_params "r" "-r" "-x"
    
    # Проверяем результат (флаг должен измениться от -r)
    assertEquals 1 $RUN_FLAG "RUN_FLAG должен быть установлен в 1"
    assert_log_info_called 0 "log_info не должен вызываться"
    assert_log_error_called 1 "log_error должен быть вызван 1 раз для невалидного параметра"
    assert_log_error_contains "Некорректный параметр" "Сообщение должно содержать текст об ошибке"
    assert_log_error_contains "-x" "Сообщение должно содержать некорректный параметр"
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
        test_parse_params_run_flag || test_result=1
        test_parse_params_no_params || test_result=1
        test_parse_params_invalid_param || test_result=1
        test_parse_params_missing_value || test_result=1
        test_parse_params_custom_allowed_params || test_result=1
        test_parse_params_default_allowed_params || test_result=1
        test_parse_params_multiple_params || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _parse_params из modules/04-ssh-port.sh"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_parse_params_run_flag
            test_parse_params_no_params
            test_parse_params_invalid_param
            test_parse_params_missing_value
            test_parse_params_custom_allowed_params
            test_parse_params_default_allowed_params
            test_parse_params_multiple_params
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _parse_params из modules/04-ssh-port.sh"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_parse_params_run_flag
        test_parse_params_no_params
        test_parse_params_invalid_param
        test_parse_params_missing_value
        test_parse_params_custom_allowed_params
        test_parse_params_default_allowed_params
        test_parse_params_multiple_params
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi