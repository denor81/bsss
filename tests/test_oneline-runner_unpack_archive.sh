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

# Перенаправляем функции логирования во временные файлы для последующей проверки
log_error() {
    echo "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $1" >> "${TEST_LOG_FILE:-/dev/null}"
}

log_info() {
    echo "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $1" >> "${TEST_LOG_FILE:-/dev/null}"
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
    local test_log_file="$test_dir/test.log"
    
    # Устанавливаем переменную для логов
    export TEST_LOG_FILE="$test_log_file"
    
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
    
    # Проверяем, что файлы распакованы (проверяем наличие любых файлов, а не конкретный путь)
    local file_count=$(find "$extract_dir" -type f | wc -l)
    if [ "$file_count" -gt 0 ]; then
        echo "[V] Файлы успешно распакованы (найдено файлов: $file_count)"
    else
        echo "[X] Файлы не распакованы"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
    unset TEST_LOG_FILE
}

# Тест 2: обработка невалидного архива
test_unpack_archive_invalid() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/invalid.tar.gz"
    local extract_dir="$test_dir/extracted"
    local test_log_file="$test_dir/test.log"
    
    # Устанавливаем переменную для логов
    export TEST_LOG_FILE="$test_log_file"
    
    # Создаем директорию для распаковки
    mkdir -p "$extract_dir"
    
    # Создаем невалидный архив (просто текстовый файл)
    echo "this is not a valid archive" > "$test_archive"
    
    # Вызываем тестируемую функцию с параметрами
    _unpack_archive "$test_archive" "$extract_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Обработка невалидного архива"
    
    # Проверяем, что в логе есть сообщение об ошибке
    if grep -q "Ошибка распаковки архива" "$test_log_file"; then
        echo "[V] Сообщение об ошибке распаковки найдено в логе"
    else
        echo "[X] Сообщение об ошибке распаковки не найдено в логе"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
    unset TEST_LOG_FILE
}

# Тест 3: обработка несуществующего файла архива
test_unpack_archive_nonexistent() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/nonexistent.tar.gz"
    local extract_dir="$test_dir/extracted"
    local test_log_file="$test_dir/test.log"
    
    # Устанавливаем переменную для логов
    export TEST_LOG_FILE="$test_log_file"
    
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
    unset TEST_LOG_FILE
}

# Тест 4: обработка ситуации, когда директория для распаковки не существует
test_unpack_archive_no_extract_dir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/test.tar.gz"
    local extract_dir="$test_dir/nonexistent/extracted"
    local test_log_file="$test_dir/test.log"
    
    # Устанавливаем переменную для логов
    export TEST_LOG_FILE="$test_log_file"
    
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
    unset TEST_LOG_FILE
}

# Тест 5: проверка работы с параметрами по умолчанию
test_unpack_archive_default_params() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/test.tar.gz"
    local extract_dir="$test_dir/extracted"
    local test_log_file="$test_dir/test.log"
    
    # Устанавливаем переменную для логов
    export TEST_LOG_FILE="$test_log_file"
    
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
    
    # Проверяем, что файлы распакованы (проверяем наличие любых файлов, а не конкретный путь)
    local file_count=$(find "$extract_dir" -type f | wc -l)
    if [ "$file_count" -gt 0 ]; then
        echo "[V] Файлы успешно распакованы с параметрами по умолчанию (найдено файлов: $file_count)"
    else
        echo "[X] Файлы не распакованы с параметрами по умолчанию"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
    unset TEST_LOG_FILE
}

# Тест 6: проверка работы с архивом формата tar.bz2
test_unpack_archive_bz2() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/test.tar.bz2"
    local extract_dir="$test_dir/extracted"
    local test_log_file="$test_dir/test.log"
    
    # Устанавливаем переменную для логов
    export TEST_LOG_FILE="$test_log_file"
    
    # Создаем директорию для распаковки
    mkdir -p "$extract_dir"
    
    # Создаем тестовый архив с файлом
    mkdir -p "$test_dir/source"
    echo "test content" > "$test_dir/source/test.txt"
    tar -cjf "$test_archive" -C "$test_dir" source/
    
    # Вызываем тестируемую функцию с параметрами
    # Ожидаем ошибку, так как функция поддерживает только tar.gz
    _unpack_archive "$test_archive" "$extract_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Попытка распаковки tar.bz2 архива"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
    unset TEST_LOG_FILE
}

# Тест 7: проверка работы с архивом формата tar.xz
test_unpack_archive_xz() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/test.tar.xz"
    local extract_dir="$test_dir/extracted"
    local test_log_file="$test_dir/test.log"
    
    # Устанавливаем переменную для логов
    export TEST_LOG_FILE="$test_log_file"
    
    # Создаем директорию для распаковки
    mkdir -p "$extract_dir"
    
    # Создаем тестовый архив с файлом
    mkdir -p "$test_dir/source"
    echo "test content" > "$test_dir/source/test.txt"
    tar -cJf "$test_archive" -C "$test_dir" source/
    
    # Вызываем тестируемую функцию с параметрами
    # Ожидаем ошибку, так как функция поддерживает только tar.gz
    _unpack_archive "$test_archive" "$extract_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Попытка распаковки tar.xz архива"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
    unset TEST_LOG_FILE
}

# Тест 8: проверка работы с пустым архивом
test_unpack_archive_empty() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_archive="$test_dir/empty.tar.gz"
    local extract_dir="$test_dir/extracted"
    local test_log_file="$test_dir/test.log"
    
    # Устанавливаем переменную для логов
    export TEST_LOG_FILE="$test_log_file"
    
    # Создаем директорию для распаковки
    mkdir -p "$extract_dir"
    
    # Создаем пустой архив
    touch "$test_dir/empty_file"
    tar -czf "$test_archive" -C "$test_dir" empty_file
    rm "$test_dir/empty_file"
    
    # Вызываем тестируемую функцию с параметрами
    _unpack_archive "$test_archive" "$extract_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Распаковка пустого архива"
    
    # Проверяем, что файлы распакованы (даже если они были пустыми)
    local file_count=$(find "$extract_dir" -type f | wc -l)
    if [ "$file_count" -gt 0 ]; then
        echo "[V] Файлы из пустого архива успешно распакованы (найдено файлов: $file_count)"
    else
        echo "[X] Файлы из пустого архива не распакованы"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
    unset TEST_LOG_FILE
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Проверяем, запущен ли тест через раннер
    if [[ "${TEST_RUNNER_MODE:-}" == "1" ]]; then
        # Режим работы через раннер - выводим только в случае ошибок
        test_result=0
        
        # Запускаем тесты и захватываем вывод
        test_unpack_archive_valid || test_result=1
        test_unpack_archive_invalid || test_result=1
        test_unpack_archive_nonexistent || test_result=1
        test_unpack_archive_no_extract_dir || test_result=1
        test_unpack_archive_default_params || test_result=1
        test_unpack_archive_bz2 || test_result=1
        test_unpack_archive_xz || test_result=1
        test_unpack_archive_empty || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _unpack_archive"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_unpack_archive_valid
            test_unpack_archive_invalid
            test_unpack_archive_nonexistent
            test_unpack_archive_no_extract_dir
            test_unpack_archive_default_params
            test_unpack_archive_bz2
            test_unpack_archive_xz
            test_unpack_archive_empty
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _unpack_archive"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_unpack_archive_valid
        test_unpack_archive_invalid
        test_unpack_archive_nonexistent
        test_unpack_archive_no_extract_dir
        test_unpack_archive_default_params
        test_unpack_archive_bz2
        test_unpack_archive_xz
        test_unpack_archive_empty
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi