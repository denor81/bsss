#!/usr/bin/env bash
# tests/test_unpack_archive.sh
# Тест для функции _unpack_archive

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
# ТЕСТЫ ФУНКЦИИ _unpack_archive
# ==========================================

# Тест 1: успешная распаковка валидного архива
test_unpack_archive_valid() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/test.tar.gz"
    local extract_dir="$test_dir/extracted"
    
    # Создаем директорию для распаковки
    mkdir -p "$extract_dir"
    
    # Создаем тестовый архив с файлом
    mkdir -p "$test_dir/source"
    echo "test content" > "$test_dir/source/test.txt"
    tar -czf "$test_archive" -C "$test_dir" source/
    
    # Вызываем тестируемую функцию с параметрами
    _unpack_archive "$test_archive" "$extract_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Распаковка валидного архива"
    
    # Проверяем, что файл распакован
    if [ -f "$extract_dir/source/test.txt" ]; then
        echo "[V] Файл успешно распакован"
    else
        echo "[X] Файл не распакован"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: обработка невалидного архива
test_unpack_archive_invalid() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/invalid.tar.gz"
    local extract_dir="$test_dir/extracted"
    
    # Создаем директорию для распаковки
    mkdir -p "$extract_dir"
    
    # Создаем невалидный архив (просто текстовый файл)
    echo "this is not a valid archive" > "$test_archive"
    
    # Вызываем тестируемую функцию с параметрами
    _unpack_archive "$test_archive" "$extract_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Обработка невалидного архива"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: обработка несуществующего файла архива
test_unpack_archive_nonexistent() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/nonexistent.tar.gz"
    local extract_dir="$test_dir/extracted"
    
    # Создаем директорию для распаковки
    mkdir -p "$extract_dir"
    
    # Не создаем архив, он не существует
    
    # Вызываем тестируемую функцию с параметрами
    _unpack_archive "$test_archive" "$extract_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Обработка несуществующего архива"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: обработка ситуации, когда директория для распаковки не существует
test_unpack_archive_no_extract_dir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/test.tar.gz"
    local extract_dir="$test_dir/nonexistent/extracted"
    
    # Создаем тестовый архив с файлом
    mkdir -p "$test_dir/source"
    echo "test content" > "$test_dir/source/test.txt"
    tar -czf "$test_archive" -C "$test_dir" source/
    
    # НЕ создаем директорию для распаковки, она не существует
    
    # Вызываем тестируемую функцию с параметрами
    _unpack_archive "$test_archive" "$extract_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Распаковка в несуществующую директорию"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: проверка работы с параметрами по умолчанию
test_unpack_archive_default_params() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/test.tar.gz"
    local extract_dir="$test_dir/extracted"
    
    # Создаем директорию для распаковки
    mkdir -p "$extract_dir"
    
    # Создаем тестовый архив с файлом
    mkdir -p "$test_dir/source"
    echo "test content" > "$test_dir/source/test.txt"
    tar -czf "$test_archive" -C "$test_dir" source/
    
    # Устанавливаем глобальные переменные для функции
    local TMPARCHIVE="$test_archive"
    local TEMP_PROJECT_DIR="$extract_dir"
    
    # Вызываем тестируемую функцию без параметров (должны использоваться значения по умолчанию)
    _unpack_archive
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Распаковка с параметрами по умолчанию"
    
    # Проверяем, что файл распакован
    if [ -f "$extract_dir/source/test.txt" ]; then
        echo "[V] Файл успешно распакован с параметрами по умолчанию"
    else
        echo "[X] Файл не распакован с параметрами по умолчанию"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _unpack_archive"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_unpack_archive_valid
    test_unpack_archive_invalid
    test_unpack_archive_nonexistent
    test_unpack_archive_no_extract_dir
    test_unpack_archive_default_params
    
    echo "============================================="
    echo "Тесты завершены"
fi