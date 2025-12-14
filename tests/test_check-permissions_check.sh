#!/usr/bin/env bash
# tests/test_check-permissions_check.sh
# Тест для функции check из modules/02-check-permissions.sh

# Подключаем тестируемый файл
# shellcheck source=../modules/02-check-permissions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/02-check-permissions.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
CURRENT_MODULE_NAME="test_check_permissions"

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ТЕСТА
# ==========================================
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

# Тест 1: когда пользователь root (EUID=0)
test_check_user_root() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию с параметром EUID=0
    local output
    output=$(check 0)
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 0 $actual_status "Пользователь root (EUID=0)"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Имеются права root" | base64)
    local expected_symbol=$(printf '%s' "[V]" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (пользователь root)"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    if [[ "$output" =~ symbol=\"([^\"]+)\" ]]; then
        local actual_symbol="${BASH_REMATCH[1]}"
        assertEquals "$expected_symbol" "$actual_symbol" "Символ (пользователь root)"
    else
        echo "[X] Не найдено поле symbol в выводе"
        return 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда пользователь имеет права sudo
test_check_user_with_sudo() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем мок-функцию для проверки sudo
    # Вместо реальной команды sudo -n true, мы будем использовать команду, которая всегда возвращает успех
    local mock_sudo_command="true"
    
    # Вызываем тестируемую функцию с параметрами: EUID не root и мок-команда для sudo
    local output
    output=$(check 1000 "$mock_sudo_command")
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 0 $actual_status "Пользователь с правами sudo"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Имеются права через sudo" | base64)
    local expected_symbol=$(printf '%s' "[V]" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (пользователь с sudo)"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    if [[ "$output" =~ symbol=\"([^\"]+)\" ]]; then
        local actual_symbol="${BASH_REMATCH[1]}"
        assertEquals "$expected_symbol" "$actual_symbol" "Символ (пользователь с sudo)"
    else
        echo "[X] Не найдено поле symbol в выводе"
        return 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: когда у пользователя нет прав
test_check_user_without_permissions() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем мок-функцию для проверки sudo, которая всегда возвращает ошибку
    local mock_sudo_command="false"
    
    # Вызываем тестируемую функцию с параметрами: EUID не root и мок-команда для sudo
    local output
    output=$(check 1000 "$mock_sudo_command")
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 1 $actual_status "Пользователь без прав"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Требуются права root или членство в группе sudo" | base64)
    local expected_symbol=$(printf '%s' "[X]" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (пользователь без прав)"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    if [[ "$output" =~ symbol=\"([^\"]+)\" ]]; then
        local actual_symbol="${BASH_REMATCH[1]}"
        assertEquals "$expected_symbol" "$actual_symbol" "Символ (пользователь без прав)"
    else
        echo "[X] Не найдено поле symbol в выводе"
        return 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: проверка работы с параметром по умолчанию (без параметров)
test_check_default_parameters() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию без параметров
    # Она будет использовать текущий EUID и команду sudo -n true 2>/dev/null
    local output
    output=$(check)
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    
    # Мы не можем предсказать точный результат, так как он зависит от текущего пользователя
    # Поэтому мы просто проверяем, что функция корректно возвращает статус
    if [[ $actual_status -eq 0 ]]; then
        echo "[V] Параметры по умолчанию (статус 0)"
    elif [[ $actual_status -eq 1 ]]; then
        echo "[V] Параметры по умолчанию (статус 1)"
    else
        echo "[X] Параметры по умолчанию (неожиданный статус: $actual_status)"
        return 1
    fi
    
    # Проверяем, что поля message и symbol присутствуют в выводе
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        echo "[V] Поле message присутствует в выводе"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    if [[ "$output" =~ symbol=\"([^\"]+)\" ]]; then
        echo "[V] Поле symbol присутствует в выводе"
    else
        echo "[X] Не найдено поле symbol в выводе"
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
        test_check_user_root || test_result=1
        test_check_user_with_sudo || test_result=1
        test_check_user_without_permissions || test_result=1
        test_check_default_parameters || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции check из modules/02-check-permissions.sh"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_check_user_root
            test_check_user_with_sudo
            test_check_user_without_permissions
            test_check_default_parameters
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции check из modules/02-check-permissions.sh"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_check_user_root
        test_check_user_with_sudo
        test_check_user_without_permissions
        test_check_default_parameters
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi