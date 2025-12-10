#!/usr/bin/env bash
# tests/test_download_archive.sh
# Тест для функции _download_archive

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
# ТЕСТЫ ФУНКЦИИ _download_archive
# ==========================================

# Тест 1: успешная загрузка архива с валидным URL
test_download_archive_valid_url() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_file="$test_dir/test.txt"
    local test_archive="$test_dir/test.tar.gz"
    
    # Создаем тестовый файл и архив
    echo "test content" > "$test_file"
    tar -czf "$test_archive" -C "$test_dir" test.txt
    
    # Создаем URL для файла
    local archive_url="file://$test_archive"
    
    # Вызываем тестируемую функцию с параметрами
    _download_archive "$archive_url" "$test_dir/downloaded.tar.gz" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Загрузка архива с валидным URL"
    
    # Проверяем, что файл загружен
    if [ -f "$test_dir/downloaded.tar.gz" ]; then
        echo "[V] Файл успешно загружен"
    else
        echo "[X] Файл не загружен"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: обработка невалидного URL
test_download_archive_invalid_url() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local invalid_url="file://$test_dir/nonexistent.tar.gz"
    
    # Вызываем тестируемую функцию с невалидным URL
    _download_archive "$invalid_url" "$test_dir/downloaded.tar.gz" false
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Обработка невалидного URL"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: проверка работы с параметрами по умолчанию
test_download_archive_default_params() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_file="$test_dir/test.txt"
    local test_archive="$test_dir/test.tar.gz"
    
    # Создаем тестовый файл и архив
    echo "test content" > "$test_file"
    tar -czf "$test_archive" -C "$test_dir" test.txt
    
    # Устанавливаем глобальные переменные для функции
    # Note: ARCHIVE_URL is readonly, so we'll pass it as a parameter instead
    local CLEANUP_COMMANDS=()
    
    # Вызываем тестируемую функцию с URL в качестве параметра
    _download_archive "file://$test_archive"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Загрузка с параметрами по умолчанию"
    
    # Проверяем, что TMPARCHIVE установлен и файл существует
    if [ -f "$TMPARCHIVE" ]; then
        echo "[V] Файл успешно загружен с параметрами по умолчанию"
    else
        echo "[X] Файл не загружен с параметрами по умолчанию"
    fi
    
    # Проверяем, что файл добавлен в CLEANUP_COMMANDS
    if [[ "${#CLEANUP_COMMANDS[@]}" -gt 0 ]]; then
        echo "[V] Файл добавлен в CLEANUP_COMMANDS"
    else
        echo "[X] Файл не добавлен в CLEANUP_COMMANDS"
    fi
    
    # Удаляем временные файлы
    rm -f "$TMPARCHIVE"
    rm -rf "$test_dir"
}

# Тест 4: проверка работы без добавления в CLEANUP_COMMANDS
test_download_archive_no_cleanup() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_file="$test_dir/test.txt"
    local test_archive="$test_dir/test.tar.gz"
    
    # Создаем тестовый файл и архив
    echo "test content" > "$test_file"
    tar -czf "$test_archive" -C "$test_dir" test.txt
    
    # Создаем URL для файла
    local archive_url="file://$test_archive"
    local CLEANUP_COMMANDS=()
    
    # Вызываем тестируемую функцию с параметром add_to_cleanup=false
    _download_archive "$archive_url" "$test_dir/downloaded.tar.gz" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Загрузка без добавления в CLEANUP_COMMANDS"
    
    # Проверяем, что файл загружен
    if [ -f "$test_dir/downloaded.tar.gz" ]; then
        echo "[V] Файл успешно загружен"
    else
        echo "[X] Файл не загружен"
    fi
    
    # Проверяем, что файл НЕ добавлен в CLEANUP_COMMANDS
    if [[ "${#CLEANUP_COMMANDS[@]}" -eq 0 ]]; then
        echo "[V] Файл не добавлен в CLEANUP_COMMANDS"
    else
        echo "[X] Файл добавлен в CLEANUP_COMMANDS"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: проверка работы с автоматически созданным временным файлом
test_download_archive_auto_tmpfile() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_file="$test_dir/test.txt"
    local test_archive="$test_dir/test.tar.gz"
    
    # Создаем тестовый файл и архив
    echo "test content" > "$test_file"
    tar -czf "$test_archive" -C "$test_dir" test.txt
    
    # Создаем URL для файла
    local archive_url="file://$test_archive"
    
    # Сохраняем старое значение TMPARCHIVE
    local old_tmparchive="$TMPARCHIVE"
    
    # Вызываем тестируемую функцию только с URL (временный файл будет создан автоматически)
    _download_archive "$archive_url" "" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Загрузка с автоматически созданным временным файлом"
    
    # Проверяем, что TMPARCHIVE установлен и файл существует
    if [ -f "$TMPARCHIVE" ]; then
        echo "[V] Временный файл успешно создан и загружен"
    else
        echo "[X] Временный файл не создан или не загружен"
    fi
    
    # Удаляем временные файлы
    rm -f "$TMPARCHIVE"
    
    # Восстанавливаем старое значение TMPARCHIVE
    TMPARCHIVE="$old_tmparchive"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _download_archive"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_download_archive_valid_url
    test_download_archive_invalid_url
    test_download_archive_default_params
    test_download_archive_no_cleanup
    test_download_archive_auto_tmpfile
    
    echo "============================================="
    echo "Тесты завершены"
fi