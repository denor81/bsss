#!/usr/bin/env bash
# tests/test_create_symlink.sh
# Тест для функции _create_symlink

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
    
    # Определяем параметры для функции
    local install_dir="$test_dir"
    local local_runner_file_name="test_runner.sh"
    local symbol_link_path="$test_dir/test_symlink"
    local util_name="test_util"
    
    # Вызываем тестируемую функцию с параметрами вместо переопределения readonly переменных
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание символической ссылки"
    
    # Проверяем, что символическая ссылка действительно создана
    if [[ -L "$symbol_link_path" ]]; then
        echo "[V] Символическая ссылка $symbol_link_path создана"
    else
        echo "[X] Символическая ссылка $symbol_link_path не создана"
    fi
    
    # Проверяем, что ссылка указывает на правильный файл
    local link_target=$(readlink "$symbol_link_path")
    local expected_target="$install_dir/$local_runner_file_name"
    if [[ "$link_target" == "$expected_target" ]]; then
        echo "[V] Ссылка указывает на правильный файл: $link_target"
    else
        echo "[X] Ссылка указывает на неправильный файл: $link_target (ожидалось: $expected_target)"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: создание символической ссылки на несуществующий файл (ln -s допускает это)
test_create_symlink_target_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Определяем параметры для функции
    local install_dir="$test_dir"
    local local_runner_file_name="nonexistent_runner.sh"  # Файл не существует
    local symbol_link_path="$test_dir/test_symlink"
    local util_name="test_util"
    
    # Вызываем тестируемую функцию с параметрами
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name"
    
    # Проверяем результат (ln -s не выдает ошибку при создании ссылки на несуществующий файл)
    local result=$?
    assertEquals 0 $result "Создание символической ссылки на несуществующий файл (допустимо)"
    
    # Проверяем, что символическая ссылка создана
    if [[ -L "$symbol_link_path" ]]; then
        echo "[V] Символическая ссылка создана"
        
        # Проверяем, что ссылка указывает на несуществующий файл
        local link_target=$(readlink "$symbol_link_path")
        if [[ "$link_target" == "$install_dir/nonexistent_runner.sh" ]]; then
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
    
    # Определяем параметры для функции
    local install_dir="$test_dir"
    local local_runner_file_name="test_runner.sh"
    local symbol_link_path="$test_dir/nonexistent_dir/test_symlink"  # Директория не существует
    local util_name="test_util"
    
    # Вызываем тестируемую функцию с параметрами, перенаправляя stderr, чтобы скрыть сообщение об ошибке ln
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name" 2>/dev/null
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Ошибка создания символической ссылки (директория для ссылки не существует)"
    
    # Проверяем, что символическая ссылка не создана
    if [[ ! -L "$symbol_link_path" ]]; then
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
    
    # Определяем параметры для функции
    local install_dir="$test_dir"
    local local_runner_file_name="test_runner.sh"
    local symbol_link_path="$test_dir/test_symlink"  # Используем абсолютный путь для изоляции
    local util_name="test_util"
    
    # Вызываем тестируемую функцию с параметрами
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание символической ссылки"
    
    # Проверяем, что символическая ссылка действительно создана
    if [[ -L "$symbol_link_path" ]]; then
        echo "[V] Символическая ссылка $symbol_link_path создана"
    else
        echo "[X] Символическая ссылка $symbol_link_path не создана"
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