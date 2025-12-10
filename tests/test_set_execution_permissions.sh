#!/usr/bin/env bash
# tests/test_set_execution_permissions.sh
# Тест для функции _set_execution_permissions

# Подключаем тестируемый файл
# shellcheck source=../lib/install_to_system_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/install_to_system_functions.sh"
# Примечание: logging.sh не подключаем, так как мы мокируем log_info

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
# ТЕСТЫ ФУНКЦИИ _set_execution_permissions
# ==========================================

# Тест 1: успешная установка прав на выполнение для .sh файлов
test_set_execution_permissions_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Переопределяем глобальную переменную для условий теста
    local INSTALL_DIR="$test_dir"
    
    # Создаем тестовые .sh файлы без прав на выполнение
    echo "#!/bin/bash" > "$INSTALL_DIR/script1.sh"
    echo "#!/bin/bash" > "$INSTALL_DIR/script2.sh"
    echo "test content" > "$INSTALL_DIR/file.txt"  # Не .sh файл
    
    # Убираем права на выполнение у .sh файлов
    chmod -x "$INSTALL_DIR"/*.sh
    
    # Проверяем, что файлы не имеют прав на выполнение
    if [[ ! -x "$INSTALL_DIR/script1.sh" ]]; then
        echo "[V] script1.sh не имеет прав на выполнение до вызова функции"
    else
        echo "[X] script1.sh уже имеет права на выполнение до вызова функции"
    fi
    
    # Вызываем тестируемую функцию
    _set_execution_permissions
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешная установка прав на выполнение"
    
    # Проверяем, что .sh файлы теперь имеют права на выполнение
    if [[ -x "$INSTALL_DIR/script1.sh" ]]; then
        echo "[V] script1.sh имеет права на выполнение после вызова функции"
    else
        echo "[X] script1.sh не имеет прав на выполнение после вызова функции"
    fi
    
    if [[ -x "$INSTALL_DIR/script2.sh" ]]; then
        echo "[V] script2.sh имеет права на выполнение после вызова функции"
    else
        echo "[X] script2.sh не имеет прав на выполнение после вызова функции"
    fi
    
    # Проверяем, что не .sh файл не изменил своих прав
    if [[ ! -x "$INSTALL_DIR/file.txt" ]]; then
        echo "[V] file.txt не имеет прав на выполнение (как и ожидалось)"
    else
        echo "[X] file.txt имеет права на выполнение (неожиданно)"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: директория без .sh файлов
test_set_execution_permissions_no_sh_files() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Переопределяем глобальную переменную для условий теста
    local INSTALL_DIR="$test_dir"
    
    # Создаем файлы не .sh расширения
    echo "test content 1" > "$INSTALL_DIR/file1.txt"
    echo "test content 2" > "$INSTALL_DIR/file2.conf"
    mkdir -p "$INSTALL_DIR/subdir"
    echo "test content 3" > "$INSTALL_DIR/subdir/file3.log"
    
    # Вызываем тестируемую функцию
    _set_execution_permissions
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Директория без .sh файлов"
    
    # Проверяем, что файлы не имеют прав на выполнение
    if [[ ! -x "$INSTALL_DIR/file1.txt" ]]; then
        echo "[V] file1.txt не имеет прав на выполнение"
    else
        echo "[X] file1.txt имеет права на выполнение"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: пустая директория
test_set_execution_permissions_empty_dir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Переопределяем глобальную переменную для условий теста
    local INSTALL_DIR="$test_dir"
    
    # Вызываем тестируемую функцию
    _set_execution_permissions
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Пустая директория"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: директория с файлами, которые уже имеют права на выполнение
test_set_execution_permissions_already_executable() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Переопределяем глобальную переменную для условий теста
    local INSTALL_DIR="$test_dir"
    
    # Создаем тестовые .sh файлы с правами на выполнение
    echo "#!/bin/bash" > "$INSTALL_DIR/script1.sh"
    echo "#!/bin/bash" > "$INSTALL_DIR/script2.sh"
    chmod +x "$INSTALL_DIR"/*.sh
    
    # Проверяем, что файлы уже имеют права на выполнение
    if [[ -x "$INSTALL_DIR/script1.sh" ]]; then
        echo "[V] script1.sh уже имеет права на выполнение перед вызовом функции"
    else
        echo "[X] script1.sh не имеет прав на выполнение перед вызовом функции"
    fi
    
    # Вызываем тестируемую функцию
    _set_execution_permissions
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файлы уже имеют права на выполнение"
    
    # Проверяем, что .sh файлы все еще имеют права на выполнение
    if [[ -x "$INSTALL_DIR/script1.sh" ]]; then
        echo "[V] script1.sh все еще имеет права на выполнение после вызова функции"
    else
        echo "[X] script1.sh не имеет прав на выполнение после вызова функции"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: директория не существует
test_set_execution_permissions_dir_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Переопределяем глобальную переменную для условий теста
    local INSTALL_DIR="$test_dir/nonexistent"
    
    # Вызываем тестируемую функцию
    _set_execution_permissions
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Директория не существует"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _set_execution_permissions"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_set_execution_permissions_success
    test_set_execution_permissions_no_sh_files
    test_set_execution_permissions_empty_dir
    test_set_execution_permissions_already_executable
    test_set_execution_permissions_dir_not_exists
    
    echo "============================================="
    echo "Тесты завершены"
fi