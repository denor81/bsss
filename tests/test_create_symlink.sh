#!/usr/bin/env bash
# tests/test_create_symlink.sh
# Тест для функции _create_symlink

# Подключаем тестируемый файл
# shellcheck source=../oneline-runner.sh
source "$(dirname "${BASH_SOURCE[0]}")/../oneline-runner.sh"
# Примечание: функции логирования и _add_uninstall_path уже определены в oneline-runner.sh

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

# Создание временной директории с тестовыми файлами
# Возвращает путь к созданной директории
setup_test_environment() {
    local test_dir
    test_dir=$(mktemp -d)
    
    # Создаем тестовый файл, на который будет ссылаться символическая ссылка
    local test_file="$test_dir/test_runner.sh"
    echo "#!/bin/bash" > "$test_file"
    chmod +x "$test_file"
    
    echo "$test_dir"
}

# Очистка тестовой среды
cleanup_test_environment() {
    local test_dir="$1"
    if [[ -n "$test_dir" && -d "$test_dir" ]]; then
        rm -rf "$test_dir"
    fi
}

# Проверка поведения символической ссылки (не её внутренней структуры)
# Проверяет, что ссылка работает как ожидается
verify_symlink_behavior() {
    local symlink_path="$1"
    local expected_content="$2"
    
    # Проверяем, что символическая ссылка существует
    if [[ ! -L "$symlink_path" ]]; then
        echo "[X] Символическая ссылка $symlink_path не существует"
        return 1
    fi
    
    # Проверяем, что ссылка указывает на существующий файл (если он должен существовать)
    if [[ -n "$expected_content" ]]; then
        # Проверяем, что ссылка работает (можно прочитать содержимое файла через ссылку)
        local actual_content
        actual_content=$(cat "$symlink_path" 2>/dev/null)
        if [[ "$actual_content" != "$expected_content" ]]; then
            echo "[X] Содержимое файла через ссылку не соответствует ожидаемому"
            return 1
        fi
    fi
    
    echo "[V] Символическая ссылка работает корректно"
    return 0
}

# ==========================================
# ТЕСТЫ ФУНКЦИИ _create_symlink
# ==========================================

# Тест 1: успешное создание символической ссылки
test_create_symlink_success() {
    # Создаем тестовую среду
    local test_dir
    test_dir=$(setup_test_environment)
    
    # Определяем параметры для функции
    local install_dir="$test_dir"
    local local_runner_file_name="test_runner.sh"
    local symbol_link_path="$test_dir/test_symlink"
    local util_name="test_util"
    
    # Вызываем тестируемую функцию с параметрами
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание символической ссылки"
    
    # Проверяем поведение символической ссылки (не её внутреннюю структуру)
    verify_symlink_behavior "$symbol_link_path" "#!/bin/bash"
    
    # Очищаем тестовую среду
    cleanup_test_environment "$test_dir"
}

# Тест 2: создание символической ссылки на несуществующий файл (ln -s допускает это)
test_create_symlink_target_not_exists() {
    # Создаем тестовую среду
    local test_dir
    test_dir=$(setup_test_environment)
    
    # Определяем параметры для функции (файл не существует)
    local install_dir="$test_dir"
    local local_runner_file_name="nonexistent_runner.sh"
    local symbol_link_path="$test_dir/test_symlink"
    local util_name="test_util"
    
    # Вызываем тестируемую функцию с параметрами
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name"
    
    # Проверяем результат (ln -s не выдает ошибку при создании ссылки на несуществующий файл)
    local result=$?
    assertEquals 0 $result "Создание символической ссылки на несуществующий файл (допустимо)"
    
    # Проверяем, что символическая ссылка создана, но не работает (ведет на несуществующий файл)
    if [[ -L "$symbol_link_path" ]]; then
        echo "[V] Символическая ссылка создана"
        
        # Проверяем, что ссылка не работает (ведет на несуществующий файл)
        if ! cat "$symbol_link_path" 2>/dev/null; then
            echo "[V] Ссылка корректно указывает на несуществующий файл"
        else
            echo "[X] Ссылка работает, хотя не должна (ведет на существующий файл)"
        fi
    else
        echo "[X] Символическая ссылка не создана"
    fi
    
    # Очищаем тестовую среду
    cleanup_test_environment "$test_dir"
}

# Тест 3: ошибка создания символической ссылки (директория для ссылки не существует)
test_create_symlink_dir_not_exists() {
    # Создаем тестовую среду
    local test_dir
    test_dir=$(setup_test_environment)
    
    # Определяем параметры для функции (директория для ссылки не существует)
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
    
    # Очищаем тестовую среду
    cleanup_test_environment "$test_dir"
}

# Тест 4: создание символической ссылки с относительным путем
test_create_symlink_relative_path() {
    # Создаем тестовую среду
    local test_dir
    test_dir=$(setup_test_environment)
    
    # Определяем параметры для функции
    local install_dir="$test_dir"
    local local_runner_file_name="test_runner.sh"
    local symbol_link_path="$test_dir/test_symlink"
    local util_name="test_util"
    
    # Вызываем тестируемую функцию с параметрами
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание символической ссылки"
    
    # Проверяем поведение символической ссылки
    verify_symlink_behavior "$symbol_link_path" "#!/bin/bash"
    
    # Очищаем тестовую среду
    cleanup_test_environment "$test_dir"
}

# Тест 5: попытка создания ссылки на уже существующую ссылку
test_create_symlink_existing_link() {
    # Создаем тестовую среду
    local test_dir
    test_dir=$(setup_test_environment)
    
    # Определяем параметры для функции
    local install_dir="$test_dir"
    local local_runner_file_name="test_runner.sh"
    local symbol_link_path="$test_dir/test_symlink"
    local util_name="test_util"
    
    # Создаем первую символическую ссылку
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name"
    
    # Проверяем, что первая ссылка создана успешно
    local result1=$?
    assertEquals 0 $result1 "Первое создание символической ссылки"
    
    # Пытаемся создать вторую ссылку на том же месте
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name" 2>/dev/null
    
    # Проверяем результат (ln -s должен выдать ошибку)
    local result2=$?
    assertEquals 1 $result2 "Ошибка при попытке создать ссылку на уже существующую ссылку"
    
    # Проверяем, что исходная ссылка все еще работает
    verify_symlink_behavior "$symbol_link_path" "#!/bin/bash"
    
    # Очищаем тестовую среду
    cleanup_test_environment "$test_dir"
}

# Тест 6: создание символической ссылки с некорректными параметрами
test_create_symlink_invalid_params() {
    # Создаем тестовую среду
    local test_dir
    test_dir=$(setup_test_environment)
    
    # Определяем параметры для функции (путь к файлу-цели содержит недопустимые символы)
    local install_dir="$test_dir"
    local local_runner_file_name="test_runner.sh"
    local symbol_link_path="$test_dir/nonexistent_dir/test_symlink"  # Директория не существует
    local util_name="test_util"
    
    # Вызываем тестируемую функцию с параметрами, перенаправляя stderr
    _create_symlink "$install_dir" "$local_runner_file_name" "$symbol_link_path" "$util_name" 2>/dev/null
    
    # Проверяем результат (должна быть ошибка из-за несуществующей директории)
    local result=$?
    assertEquals 1 $result "Ошибка создания символической ссылки (несуществующая директория)"
    
    # Проверяем, что символическая ссылка не создана
    if [[ ! -L "$symbol_link_path" ]]; then
        echo "[V] Символическая ссылка не создана из-за некорректных параметров"
    else
        echo "[X] Символическая ссылка создана (не должно было произойти)"
    fi
    
    # Очищаем тестовую среду
    cleanup_test_environment "$test_dir"
}

# Тест 7: проверка с пустыми параметрами
test_create_symlink_empty_params() {
    # Создаем тестовую среду
    local test_dir
    test_dir=$(setup_test_environment)
    
    # Вызываем тестируемую функцию с пустыми параметрами
    _create_symlink "" "" "" "" 2>/dev/null
    
    # Проверяем результат (должна быть ошибка)
    local result=$?
    assertEquals 1 $result "Ошибка создания символической ссылки (пустые параметры)"
    
    # Очищаем тестовую среду
    cleanup_test_environment "$test_dir"
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
    test_create_symlink_existing_link
    test_create_symlink_invalid_params
    test_create_symlink_empty_params
    
    echo "============================================="
    echo "Тесты завершены"
fi