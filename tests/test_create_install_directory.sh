#!/usr/bin/env bash
# tests/test_create_install_directory.sh
# Тест для функции _create_install_directory

# Подключаем тестируемый файл
# shellcheck source=../oneline-runner.sh
source "$(dirname "${BASH_SOURCE[0]}")/../oneline-runner.sh"
# Примечание: функции логирования и _add_uninstall_path уже определены в oneline-runner.sh

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

# Мокируем log_info, чтобы избежать вывода в нашем формате
log_info() {
    : # Ничего не делаем, подавляем вывод
}

# Мокируем log_error, чтобы избежать вывода в нашем формате
log_error() {
    : # Ничего не делаем, подавляем вывод
}

# Мокируем _add_uninstall_path, чтобы избежать побочных эффектов
_add_uninstall_path() {
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
# ТЕСТЫ ФУНКЦИИ _create_install_directory
# ==========================================

# Тест 1: успешное создание директории
test_create_install_directory_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    _create_install_directory "$test_dir/test_install_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание директории"
    
    # Проверяем, что директория действительно создана
    if [[ -d "$test_dir/test_install_dir" ]]; then
        echo "[V] Директория $test_dir/test_install_dir создана"
    else
        echo "[X] Директория $test_dir/test_install_dir не создана"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: создание директории с ошибкой (файл с таким же именем существует)
test_create_install_directory_file_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем файл с таким же именем, как директория, которую мы пытаемся создать
    touch "$test_dir/test_install_dir"
    
    # Вызываем тестируемую функцию с параметром, перенаправляя stderr, чтобы скрыть сообщение об ошибке mkdir
    _create_install_directory "$test_dir/test_install_dir" 2>/dev/null
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Ошибка создания директории (файл с таким же именем существует)"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: создание уже существующей директории
test_create_install_directory_already_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем директорию заранее
    mkdir -p "$test_dir/test_install_dir"
    
    # Вызываем тестируемую функцию с параметром
    _create_install_directory "$test_dir/test_install_dir"
    
    # Проверяем результат (должна быть успешной, так как mkdir -p не выдает ошибку для существующих директорий)
    local result=$?
    assertEquals 0 $result "Создание уже существующей директории"
    
    # Проверяем, что директория все еще существует
    if [[ -d "$test_dir/test_install_dir" ]]; then
        echo "[V] Директория $test_dir/test_install_dir существует"
    else
        echo "[X] Директория $test_dir/test_install_dir не существует"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: создание вложенной директории
test_create_install_directory_nested() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем путь с вложенными директориями
    local nested_dir="$test_dir/level1/level2/level3"
    
    # Вызываем тестируемую функцию с параметром
    _create_install_directory "$nested_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Создание вложенной директории"
    
    # Проверяем, что все вложенные директории созданы
    if [[ -d "$nested_dir" ]]; then
        echo "[V] Вложенная директория $nested_dir создана"
    else
        echo "[X] Вложенная директория $nested_dir не создана"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _create_install_directory"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_create_install_directory_success
    test_create_install_directory_file_exists
    test_create_install_directory_already_exists
    test_create_install_directory_nested
    
    echo "============================================="
    echo "Тесты завершены"
fi