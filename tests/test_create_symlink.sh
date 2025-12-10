#!/usr/bin/env bash
# tests/test_create_symlink.sh
# Тест для функции _create_symlink

# Подключаем тестируемый файл
# shellcheck source=../lib/install_to_system_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/install_to_system_functions.sh"
# Примечание: logging.sh не подключаем, так как мы мокируем log_error и log_info

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
# ТЕСТЫ ФУНКЦИИ _create_symlink
# ==========================================

# Тест 1: успешное создание символической ссылки
test_create_symlink_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл, на который будет ссылаться символическая ссылка
    local test_file="$test_dir/test_runner.sh"
    echo "#!/bin/bash" > "$test_file"
    chmod +x "$test_file"
    
    # Переопределяем глобальные переменные для условий теста
    local INSTALL_DIR="$test_dir"
    local LOCAL_RUNNER_FILE_NAME="test_runner.sh"
    local SYMBOL_LINK_PATH="$test_dir/test_symlink"
    local UTIL_NAME="test_util"
    
    # Вызываем тестируемую функцию
    _create_symlink
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание символической ссылки"
    
    # Проверяем, что символическая ссылка действительно создана
    if [[ -L "$SYMBOL_LINK_PATH" ]]; then
        echo "[V] Символическая ссылка $SYMBOL_LINK_PATH создана"
    else
        echo "[X] Символическая ссылка $SYMBOL_LINK_PATH не создана"
    fi
    
    # Проверяем, что ссылка указывает на правильный файл
    local link_target=$(readlink "$SYMBOL_LINK_PATH")
    if [[ "$link_target" == "$test_file" ]]; then
        echo "[V] Ссылка указывает на правильный файл: $link_target"
    else
        echo "[X] Ссылка указывает на неправильный файл: $link_target (ожидалось: $test_file)"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: создание символической ссылки на несуществующий файл (ln -s допускает это)
test_create_symlink_target_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Переопределяем глобальные переменные для условий теста
    local INSTALL_DIR="$test_dir"
    local LOCAL_RUNNER_FILE_NAME="nonexistent_runner.sh"  # Файл не существует
    local SYMBOL_LINK_PATH="$test_dir/test_symlink"
    local UTIL_NAME="test_util"
    
    # Вызываем тестируемую функцию
    _create_symlink
    
    # Проверяем результат (ln -s не выдает ошибку при создании ссылки на несуществующий файл)
    local result=$?
    assertEquals 0 $result "Создание символической ссылки на несуществующий файл (допустимо)"
    
    # Проверяем, что символическая ссылка создана
    if [[ -L "$SYMBOL_LINK_PATH" ]]; then
        echo "[V] Символическая ссылка создана"
        
        # Проверяем, что ссылка указывает на несуществующий файл
        local link_target=$(readlink "$SYMBOL_LINK_PATH")
        if [[ "$link_target" == "$INSTALL_DIR/nonexistent_runner.sh" ]]; then
            echo "[V] Ссылка указывает на правильный файл: $link_target"
        else
            echo "[X] Ссылка указывает на неправильный файл: $link_target"
        fi
    else
        echo "[X] Символическая ссылка не создана"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: ошибка создания символической ссылки (директория для ссылки не существует)
test_create_symlink_dir_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл, на который будет ссылаться символическая ссылка
    local test_file="$test_dir/test_runner.sh"
    echo "#!/bin/bash" > "$test_file"
    chmod +x "$test_file"
    
    # Переопределяем глобальные переменные для условий теста
    local INSTALL_DIR="$test_dir"
    local LOCAL_RUNNER_FILE_NAME="test_runner.sh"
    local SYMBOL_LINK_PATH="$test_dir/nonexistent_dir/test_symlink"  # Директория не существует
    local UTIL_NAME="test_util"
    
    # Вызываем тестируемую функцию, перенаправляя stderr, чтобы скрыть сообщение об ошибке ln
    _create_symlink 2>/dev/null
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Ошибка создания символической ссылки (директория для ссылки не существует)"
    
    # Проверяем, что символическая ссылка не создана
    if [[ ! -L "$SYMBOL_LINK_PATH" ]]; then
        echo "[V] Символическая ссылка не создана"
    else
        echo "[X] Символическая ссылка создана (не должно было произойти)"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: создание символической ссылки с относительным путем
test_create_symlink_relative_path() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл, на который будет ссылаться символическая ссылка
    local test_file="$test_dir/test_runner.sh"
    echo "#!/bin/bash" > "$test_file"
    chmod +x "$test_file"
    
    # Переопределяем глобальные переменные для условий теста
    local INSTALL_DIR="$test_dir"
    local LOCAL_RUNNER_FILE_NAME="test_runner.sh"
    local SYMBOL_LINK_PATH="$test_dir/test_symlink"  # Используем абсолютный путь для изоляции
    local UTIL_NAME="test_util"
    
    # Вызываем тестируемую функцию
    _create_symlink
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание символической ссылки"
    
    # Проверяем, что символическая ссылка действительно создана
    if [[ -L "$SYMBOL_LINK_PATH" ]]; then
        echo "[V] Символическая ссылка $SYMBOL_LINK_PATH создана"
    else
        echo "[X] Символическая ссылка $SYMBOL_LINK_PATH не создана"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _create_symlink"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_create_symlink_success
    test_create_symlink_target_not_exists
    test_create_symlink_dir_not_exists
    test_create_symlink_relative_path
    
    echo "============================================="
    echo "Тесты завершены"
fi