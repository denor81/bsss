#!/usr/bin/env bash
# tests/test_check_symlink_exists.sh
# Тест для функции _check_symlink_exists

# Подключаем тестируемый файл
# shellcheck source=../lib/install_to_system_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/install_to_system_functions.sh"
# Примечание: logging.sh не подключаем, так как мы мокируем log_error

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
# (переменные для тестируемой функции определяются в каждом тесте локально)

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ТЕСТА
# ==========================================
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
    
    # Переопределяем глобальную переменную для условий теста
    local SYMBOL_LINK_PATH="$test_dir/test_symlink"
    
    # Вызываем тестируемую функцию
    _check_symlink_exists
    
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
    
    # Переопределяем глобальную переменную для условий теста
    local SYMBOL_LINK_PATH="$test_dir/test_symlink"
    
    # Создаем тестовый файл и символическую ссылку
    touch "$test_dir/test_file"
    ln -s "$test_dir/test_file" "$SYMBOL_LINK_PATH"
    
    # Вызываем тестируемую функцию
    _check_symlink_exists
    
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
    
    # Переопределяем глобальную переменную для условий теста
    local SYMBOL_LINK_PATH="$test_dir/test_file"
    
    # Создаем обычный файл (не символическую ссылку)
    touch "$SYMBOL_LINK_PATH"
    
    # Вызываем тестируемую функцию
    _check_symlink_exists
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Обычный файл (не ссылка)"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _check_symlink_exists"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_check_symlink_exists_not_exists
    test_check_symlink_exists_exists
    test_check_symlink_exists_regular_file
    
    echo "============================================="
    echo "Тесты завершены"
fi