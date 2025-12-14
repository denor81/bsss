#!/usr/bin/env bash
# tests/test_check-sys-reload_check.sh
# Тест для функции check

# Подключаем тестируемый файл
# shellcheck source=../modules/03-check-sys-reload.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/03-check-sys-reload.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
CURRENT_MODULE_NAME="test_check_sys_reload"

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ТЕСТА
# ==========================================
# Переопределяем trap, чтобы избежать вызова cleanup_handler
trap() {
    : # Ничего не делаем, подавляем trap
}

# Переопределяем cleanup_handler, чтобы избежать очистки
cleanup_handler() {
    : # Ничего не делаем, подавляем cleanup
}

# Мокируем функции логирования, чтобы избежать вывода в нашем формате
log_error() {
    : # Ничего не делаем, подавляем вывод
}

log_info() {
    : # Ничего не делаем, подавляем вывод
}

log_success() {
    : # Ничего не делаем, подавляем вывод
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
# ТЕСТЫ ФУНКЦИИ check
# ==========================================

# Тест 1: когда файл перезагрузки не существует
test_check_reboot_file_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_reboot_file="$test_dir/reboot-required"
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    local output
    output=$(check "$test_reboot_file")
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 0 $actual_status "Файл перезагрузки не существует"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Перезагрузка не требуется" | base64)
    local expected_symbol=$(printf '%s' "[V]" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (файл не существует)"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    if [[ "$output" =~ symbol=\"([^\"]+)\" ]]; then
        local actual_symbol="${BASH_REMATCH[1]}"
        assertEquals "$expected_symbol" "$actual_symbol" "Символ (файл не существует)"
    else
        echo "[X] Не найдено поле symbol в выводе"
        return 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда файл перезагрузки существует
test_check_reboot_file_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_reboot_file="$test_dir/reboot-required"
    
    # Создаем файл перезагрузки
    touch "$test_reboot_file"
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    local output
    output=$(check "$test_reboot_file")
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 1 $actual_status "Файл перезагрузки существует"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Требуется перезагрузка системы" | base64)
    local expected_symbol=$(printf '%s' "[X]" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (файл существует)"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    if [[ "$output" =~ symbol=\"([^\"]+)\" ]]; then
        local actual_symbol="${BASH_REMATCH[1]}"
        assertEquals "$expected_symbol" "$actual_symbol" "Символ (файл существует)"
    else
        echo "[X] Не найдено поле symbol в выводе"
        return 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: проверка работы с параметром по умолчанию (без параметров)
test_check_default_parameter() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Проверяем, что функция работает без параметров
    # Поскольку REBOOT_REQUIRED_FILE является readonly и указывает на /var/run/reboot-required,
    # мы проверим, что функция корректно работает без параметров и возвращает ожидаемый результат
    # для отсутствующего файла (так как /var/run/reboot-required обычно не существует в тестовой среде)
    
    local output
    output=$(check)
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 0 $actual_status "Файл перезагрузки не существует (параметр по умолчанию)"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Перезагрузка не требуется" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (параметр по умолчанию)"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Проверяем, запущен ли тест через раннер
    if [[ "${TEST_RUNNER_MODE:-}" == "1" ]]; then
        # Режим работы через раннер - выводим только в случае ошибок
        test_output=""
        test_result=0
        
        # Запускаем тесты и захватываем вывод
        test_check_reboot_file_not_exists || test_result=1
        test_check_reboot_file_exists || test_result=1
        test_check_default_parameter || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции check"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_check_reboot_file_not_exists
            test_check_reboot_file_exists
            test_check_default_parameter
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции check"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_check_reboot_file_not_exists
        test_check_reboot_file_exists
        test_check_default_parameter
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi