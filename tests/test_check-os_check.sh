#!/usr/bin/env bash
# tests/test_check-os_check.sh
# Тест для функции check из modules/01-check-os.sh

# Подключаем тестируемый файл
# shellcheck source=../modules/01-check-os.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/01-check-os.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
CURRENT_MODULE_NAME="test_check_os"

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

# Тест 1: когда ОС поддерживается (ubuntu)
test_check_supported_os() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_os_release_file="$test_dir/os-release"
    
    # Создаем тестовый файл os-release с поддерживаемой ОС
    cat > "$test_os_release_file" << EOF
ID=ubuntu
VERSION_ID="20.04"
EOF
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    local output
    output=$(check "$test_os_release_file" "ubuntu")
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 0 $actual_status "Поддерживаемая ОС (ubuntu)"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Текущая система Ubuntu 20.04 поддерживается" | base64)
    local expected_symbol=$(printf '%s' "[V]" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (поддерживаемая ОС)"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    if [[ "$output" =~ symbol=\"([^\"]+)\" ]]; then
        local actual_symbol="${BASH_REMATCH[1]}"
        assertEquals "$expected_symbol" "$actual_symbol" "Символ (поддерживаемая ОС)"
    else
        echo "[X] Не найдено поле symbol в выводе"
        return 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда ОС не поддерживается
test_check_unsupported_os() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_os_release_file="$test_dir/os-release"
    
    # Создаем тестовый файл os-release с неподдерживаемой ОС
    cat > "$test_os_release_file" << EOF
ID=centos
VERSION_ID="7"
EOF
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    local output
    output=$(check "$test_os_release_file" "ubuntu")
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 1 $actual_status "Неподдерживаемая ОС (centos)"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "centos не поддерживается, поддерживается только Ubuntu" | base64)
    local expected_symbol=$(printf '%s' "[X]" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (неподдерживаемая ОС)"
    else
        echo "[X] Не найдено поле message в выводе"
        return 1
    fi
    
    if [[ "$output" =~ symbol=\"([^\"]+)\" ]]; then
        local actual_symbol="${BASH_REMATCH[1]}"
        assertEquals "$expected_symbol" "$actual_symbol" "Символ (неподдерживаемая ОС)"
    else
        echo "[X] Не найдено поле symbol в выводе"
        return 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: когда файл os-release не существует
test_check_os_release_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_os_release_file="$test_dir/os-release"
    
    # Не создаем файл os-release, он не должен существовать
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    local output
    output=$(check "$test_os_release_file" "ubuntu")
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 1 $actual_status "Файл os-release не существует"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Файл $test_os_release_file не наден" | base64)
    local expected_symbol=$(printf '%s' "[X]" | base64)
    
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

# Тест 4: проверка работы с параметром по умолчанию (без параметров)
test_check_default_parameters() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_os_release_file="$test_dir/os-release"
    
    # Создаем тестовый файл os-release с поддерживаемой ОС
    cat > "$test_os_release_file" << EOF
ID=ubuntu
VERSION_ID="22.04"
EOF
    
    # Переопределяем readonly переменные через локальные переменные в функции
    # Это невозможно сделать напрямую, поэтому мы вызываем функцию с параметрами
    
    # Вызываем тестируемую функцию без параметров, но с переопределенными переменными
    local output
    output=$(check "$test_os_release_file")
    
    # Проверяем статус из вывода функции
    local actual_status=0
    if [[ "$output" =~ status=([0-9]+) ]]; then
        actual_status="${BASH_REMATCH[1]}"
    fi
    assertEquals 0 $actual_status "Параметры по умолчанию (ubuntu)"
    
    # Проверяем содержимое вывода
    local expected_message=$(printf '%s' "Текущая система Ubuntu 22.04 поддерживается" | base64)
    
    if [[ "$output" =~ message=\"([^\"]+)\" ]]; then
        local actual_message="${BASH_REMATCH[1]}"
        assertEquals "$expected_message" "$actual_message" "Сообщение (параметры по умолчанию)"
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
        test_check_supported_os || test_result=1
        test_check_unsupported_os || test_result=1
        test_check_os_release_not_exists || test_result=1
        test_check_default_parameters || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции check из modules/01-check-os.sh"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_check_supported_os
            test_check_unsupported_os
            test_check_os_release_not_exists
            test_check_default_parameters
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции check из modules/01-check-os.sh"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_check_supported_os
        test_check_unsupported_os
        test_check_os_release_not_exists
        test_check_default_parameters
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi