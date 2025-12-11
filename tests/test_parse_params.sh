#!/usr/bin/env bash
# tests/test_parse_params.sh
# Тест для функции _parse_params

# Подключаем тестируемый файл
# shellcheck source=../local-runner.sh
source "$(dirname "${BASH_SOURCE[0]}")/../local-runner.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
# (переменные для тестируемой функции определяются в каждом тесте локально)

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ТЕСТА
# ==========================================
# Глобальные переменные для отслеживания вызовов log_info
LOG_INFO_CALLS=0
LOG_INFO_MESSAGES=()

log_info() {
    LOG_INFO_CALLS=$((LOG_INFO_CALLS + 1))
    LOG_INFO_MESSAGES+=("$*")
}

reset_log_info() {
    LOG_INFO_CALLS=0
    LOG_INFO_MESSAGES=()
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

# Тест 1: проверка парсинга параметра -h (HELP_FLAG)
test_parse_params_help_flag() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию с параметром -h
    _parse_params "hu" "-h"
    
    # Проверяем результат
    assertEquals 1 $HELP_FLAG "HELP_FLAG должен быть установлен в 1"
    assertEquals 0 $UNINSTALL_FLAG "UNINSTALL_FLAG должен остаться 0"
    assert_log_info_called 0 "log_info не должен вызываться при валидном параметре -h"
}

# Тест 2: проверка парсинга параметра -u (UNINSTALL_FLAG)
test_parse_params_uninstall_flag() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию с параметром -u
    _parse_params "hu" "-u"
    
    # Проверяем результат
    assertEquals 0 $HELP_FLAG "HELP_FLAG должен остаться 0"
    assertEquals 1 $UNINSTALL_FLAG "UNINSTALL_FLAG должен быть установлен в 1"
    assert_log_info_called 0 "log_info не должен вызываться при валидном параметре -u"
}

# Тест 3: проверка парсинга обоих параметров вместе (-h -u)
test_parse_params_both_flags() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию с параметрами -h -u
    _parse_params "hu" "-h" "-u"
    
    # Проверяем результат
    assertEquals 1 $HELP_FLAG "HELP_FLAG должен быть установлен в 1"
    assertEquals 1 $UNINSTALL_FLAG "UNINSTALL_FLAG должен быть установлен в 1"
    assert_log_info_called 0 "log_info не должен вызываться при валидных параметрах"
}

# Тест 4: проверка некорректного параметра
test_parse_params_invalid_param() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию с некорректным параметром -x
    _parse_params "hu" "-x"
    
    # Проверяем результат (флаги не должны измениться)
    assertEquals 0 $HELP_FLAG "HELP_FLAG должен остаться 0"
    assertEquals 0 $UNINSTALL_FLAG "UNINSTALL_FLAG должен остаться 0"
    assert_log_info_called 1 "log_info должен быть вызван 1 раз при невалидном параметре"
    assert_log_info_contains "Некорректный параметр" "Сообщение должно содержать текст об ошибке"
    assert_log_info_contains "-x" "Сообщение должно содержать некорректный параметр"
}

# Тест 5: проверка параметра, требующего значение (реальная проверка!)
test_parse_params_missing_value() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию с параметром, требующим значение
    # Теперь u требует значение (: после u)
    _parse_params "hu:" "-u"
    
    # Проверяем результат
    assertEquals 0 $HELP_FLAG "HELP_FLAG должен остаться 0"
    assertEquals 0 $UNINSTALL_FLAG "UNINSTALL_FLAG не должен устанавливаться без значения"
    assert_log_info_called 1 "log_info должен быть вызван при отсутствии значения"
    assert_log_info_contains "требует значение" "Сообщение должно указывать на отсутствие значения"
    assert_log_info_contains "-u" "Сообщение должно содержать проблемный параметр"
}

# Тест 6: проверка работы с пустым набором параметров
test_parse_params_empty_params() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию без параметров
    _parse_params "hu"
    
    # Проверяем результат (флаги не должны измениться)
    assertEquals 0 $HELP_FLAG "HELP_FLAG должен остаться 0"
    assertEquals 0 $UNINSTALL_FLAG "UNINSTALL_FLAG должен остаться 0"
    assert_log_info_called 0 "log_info не должен вызываться без параметров"
}

# Тест 7: комбинированные короткие параметры (-hu)
test_parse_params_combined_flags() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию с комбинированными параметрами -hu
    _parse_params "hu" "-hu"
    
    # Проверяем результат
    assertEquals 1 $HELP_FLAG "HELP_FLAG должен быть установлен в 1"
    assertEquals 1 $UNINSTALL_FLAG "UNINSTALL_FLAG должен быть установлен в 1"
    assert_log_info_called 0 "log_info не должен вызываться"
}

# Тест 8: повторяющиеся параметры (-h -h)
test_parse_params_duplicate_flags() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию с повторяющимися параметрами -h -h
    _parse_params "hu" "-h" "-h"
    
    # Проверяем результат
    assertEquals 1 $HELP_FLAG "HELP_FLAG должен быть установлен в 1 (остается 1)"
    assertEquals 0 $UNINSTALL_FLAG "UNINSTALL_FLAG должен остаться 0"
    assert_log_info_called 0 "log_info не должен вызываться"
}

# Тест 9: параметры в разном порядке
test_parse_params_reverse_order() {
    # Сбрасываем флаги перед тестом
    HELP_FLAG=0
    UNINSTALL_FLAG=0
    reset_log_info
    
    # Вызываем тестируемую функцию с параметрами в обратном порядке -u -h
    _parse_params "hu" "-u" "-h"
    
    # Проверяем результат
    assertEquals 1 $HELP_FLAG "HELP_FLAG должен быть установлен в 1"
    assertEquals 1 $UNINSTALL_FLAG "UNINSTALL_FLAG должен быть установлен в 1"
    assert_log_info_called 0 "log_info не должен вызываться"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _parse_params"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_parse_params_help_flag
    test_parse_params_uninstall_flag
    test_parse_params_both_flags
    test_parse_params_invalid_param
    test_parse_params_missing_value
    test_parse_params_empty_params
    test_parse_params_combined_flags
    test_parse_params_duplicate_flags
    test_parse_params_reverse_order
    
    echo "============================================="
    echo "Тесты завершены"
fi