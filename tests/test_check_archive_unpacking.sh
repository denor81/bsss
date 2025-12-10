#!/usr/bin/env bash
# tests/test_check_archive_unpacking.sh
# Тест для функции _check_archive_unpacking

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

# Мокируем функции логирования, чтобы избежать вывода в нашем формате
log_error() {
    : # Ничего не делаем, подавляем вывод
}

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
# ТЕСТЫ ФУНКЦИИ _check_archive_unpacking
# ==========================================

# Тест 1: когда искомый файл существует в директории
test_check_archive_unpacking_file_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем искомый файл в директории
    touch "$test_dir/local-runner.sh"
    
    # Вызываем тестируемую функцию с параметрами
    _check_archive_unpacking "$test_dir" "local-runner.sh"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файл существует в директории"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда искомый файл не существует в директории
test_check_archive_unpacking_file_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем другой файл, но не искомый
    touch "$test_dir/another-file.sh"
    
    # Вызываем тестируемую функцию с параметрами
    _check_archive_unpacking "$test_dir" "local-runner.sh"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Файл не существует в директории"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: когда директория пуста
test_check_archive_unpacking_empty_dir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Директория остается пустой
    
    # Вызываем тестируемую функцию с параметрами
    _check_archive_unpacking "$test_dir" "local-runner.sh"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Пустая директория"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: когда файл существует в поддиректории
test_check_archive_unpacking_file_in_subdir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем поддиректорию и помещаем туда искомый файл
    mkdir -p "$test_dir/subdir"
    touch "$test_dir/subdir/local-runner.sh"
    
    # Вызываем тестируемую функцию с параметрами
    _check_archive_unpacking "$test_dir" "local-runner.sh"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файл существует в поддиректории"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: проверка работы с третьим параметром (прямой путь к файлу)
test_check_archive_unpacking_with_path_param() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем искомый файл в поддиректории
    mkdir -p "$test_dir/subdir"
    touch "$test_dir/subdir/local-runner.sh"
    
    # Вызываем тестируемую функцию с прямым путем к файлу
    _check_archive_unpacking "$test_dir" "local-runner.sh" "$test_dir/subdir/local-runner.sh"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файл найден по прямому пути"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 6: когда файл не найден в директории и третий параметр не указан
test_check_archive_unpacking_file_not_found() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Не создаем искомый файл в директории
    
    # Вызываем тестируемую функцию без третьего параметра
    _check_archive_unpacking "$test_dir" "local-runner.sh"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Файл не найден"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _check_archive_unpacking"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_check_archive_unpacking_file_exists
    test_check_archive_unpacking_file_not_exists
    test_check_archive_unpacking_empty_dir
    test_check_archive_unpacking_file_in_subdir
    test_check_archive_unpacking_with_path_param
    test_check_archive_unpacking_file_not_found
    
    echo "============================================="
    echo "Тесты завершены"
fi