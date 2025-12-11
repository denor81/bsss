#!/usr/bin/env bash
# tests/test_check_symlink_exists.sh
# Тест для функции _check_symlink_exists

# Подключаем тестируемый файл
# shellcheck source=../oneline-runner.sh
source "$(dirname "${BASH_SOURCE[0]}")/../oneline-runner.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
# (переменные для тестируемой функции определяются в каждом тесте локально)

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

# Мокируем log_error, чтобы избежать вывода в нашем формате
log_error() {
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
# ТЕСТЫ ФУНКЦИИ _check_symlink_exists
# ==========================================

# Тест 1: когда символическая ссылка не существует
test_check_symlink_exists_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    _check_symlink_exists "$test_dir/test_symlink"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Ссылка не существует"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда символическая ссылка существует
test_check_symlink_exists_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл и символическую ссылку
    touch "$test_dir/test_file"
    ln -s "$test_dir/test_file" "$test_dir/test_symlink"
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    _check_symlink_exists "$test_dir/test_symlink"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Ссылка существует"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: когда путь существует, но не является символической ссылкой
test_check_symlink_exists_regular_file() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем обычный файл (не символическую ссылку)
    touch "$test_dir/test_file"
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    _check_symlink_exists "$test_dir/test_file"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Обычный файл (не ссылка)"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: проверка битой символической ссылки (ссылка существует, но указывает на несуществующий файл)
test_check_symlink_exists_broken() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем символическую ссылку на несуществующий файл
    ln -s "$test_dir/nonexistent_file" "$test_dir/broken_symlink"
    
    # Вызываем тестируемую функцию с параметром
    _check_symlink_exists "$test_dir/broken_symlink"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Битая символическая ссылка"
    
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
        test_check_symlink_exists_not_exists || test_result=1
        test_check_symlink_exists_exists || test_result=1
        test_check_symlink_exists_regular_file || test_result=1
        test_check_symlink_exists_broken || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _check_symlink_exists"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_check_symlink_exists_not_exists
            test_check_symlink_exists_exists
            test_check_symlink_exists_regular_file
            test_check_symlink_exists_broken
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _check_symlink_exists"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_check_symlink_exists_not_exists
        test_check_symlink_exists_exists
        test_check_symlink_exists_regular_file
        test_check_symlink_exists_broken
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi