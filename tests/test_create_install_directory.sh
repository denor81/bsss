#!/usr/bin/env bash
# tests/test_create_install_directory.sh
# Тест для функции _create_install_directory

# Подключаем тестируемый файл
# shellcheck source=../lib/install_to_system_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/install_to_system_functions.sh"
# Примечание: logging.sh не подключаем, так как мы мокируем log_error и log_info
# Примечание: common.sh не подключаем, так как мы мокируем _add_uninstall_path

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
# (переменные для тестируемой функции определяются в каждом тесте локально)

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ТЕСТА
# ==========================================
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
    
    # Переопределяем глобальную переменную для условий теста
    local INSTALL_DIR="$test_dir/test_install_dir"
    
    # Вызываем тестируемую функцию
    _create_install_directory
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание директории"
    
    # Проверяем, что директория действительно создана
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "[V] Директория $INSTALL_DIR создана"
    else
        echo "[X] Директория $INSTALL_DIR не создана"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: создание директории с ошибкой (файл с таким же именем существует)
test_create_install_directory_file_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Переопределяем глобальную переменную для условий теста
    local INSTALL_DIR="$test_dir/test_install_dir"
    
    # Создаем файл с таким же именем, как директория, которую мы пытаемся создать
    touch "$INSTALL_DIR"
    
    # Вызываем тестируемую функцию, перенаправляя stderr, чтобы скрыть сообщение об ошибке mkdir
    _create_install_directory 2>/dev/null
    
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
    local INSTALL_DIR="$test_dir/test_install_dir"
    mkdir -p "$INSTALL_DIR"
    
    # Вызываем тестируемую функцию
    _create_install_directory
    
    # Проверяем результат (должна быть успешной, так как mkdir -p не выдает ошибку для существующих директорий)
    local result=$?
    assertEquals 0 $result "Создание уже существующей директории"
    
    # Проверяем, что директория все еще существует
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "[V] Директория $INSTALL_DIR существует"
    else
        echo "[X] Директория $INSTALL_DIR не существует"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: создание вложенной директории
test_create_install_directory_nested() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Переопределяем глобальную переменную для условий теста
    # Создаем путь с вложенными директориями
    local INSTALL_DIR="$test_dir/level1/level2/level3"
    
    # Вызываем тестируемую функцию
    _create_install_directory
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Создание вложенной директории"
    
    # Проверяем, что все вложенные директории созданы
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "[V] Вложенная директория $INSTALL_DIR создана"
    else
        echo "[X] Вложенная директория $INSTALL_DIR не создана"
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