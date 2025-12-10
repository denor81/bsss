#!/usr/bin/env bash
# tests/test_copy_installation_files.sh
# Тест для функции _copy_installation_files

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
# ТЕСТЫ ФУНКЦИИ _copy_installation_files
# ==========================================

# Тест 1: успешное копирование файлов
test_copy_installation_files_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем исходную директорию с файлами
    local source_dir="$test_dir/source"
    mkdir -p "$source_dir"
    
    # Создаем тестовые файлы в исходной директории
    echo "test content 1" > "$source_dir/file1.txt"
    echo "test content 2" > "$source_dir/file2.txt"
    mkdir -p "$source_dir/subdir"
    echo "test content 3" > "$source_dir/subdir/file3.txt"
    
    # Переопределяем глобальные переменные для условий теста
    local TMP_LOCAL_RUNNER_PATH="$source_dir/some_runner.sh"
    local INSTALL_DIR="$test_dir/install"
    
    # Создаем директорию назначения
    mkdir -p "$INSTALL_DIR"
    
    # Вызываем тестируемую функцию
    _copy_installation_files
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное копирование файлов"
    
    # Проверяем, что файлы скопированы
    if [[ -f "$INSTALL_DIR/file1.txt" ]]; then
        echo "[V] Файл file1.txt скопирован"
    else
        echo "[X] Файл file1.txt не скопирован"
    fi
    
    if [[ -f "$INSTALL_DIR/file2.txt" ]]; then
        echo "[V] Файл file2.txt скопирован"
    else
        echo "[X] Файл file2.txt не скопирован"
    fi
    
    if [[ -f "$INSTALL_DIR/subdir/file3.txt" ]]; then
        echo "[V] Файл subdir/file3.txt скопирован"
    else
        echo "[X] Файл subdir/file3.txt не скопирован"
    fi
    
    # Проверяем содержимое скопированных файлов
    local content1=$(cat "$INSTALL_DIR/file1.txt")
    if [[ "$content1" == "test content 1" ]]; then
        echo "[V] Содержимое файла file1.txt корректно"
    else
        echo "[X] Содержимое файла file1.txt некорректно"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: ошибка копирования (директория назначения не существует)
test_copy_installation_files_no_dest_dir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем исходную директорию с файлами
    local source_dir="$test_dir/source"
    mkdir -p "$source_dir"
    
    # Создаем тестовый файл в исходной директории
    echo "test content" > "$source_dir/file1.txt"
    
    # Переопределяем глобальные переменные для условий теста
    local TMP_LOCAL_RUNNER_PATH="$source_dir/some_runner.sh"
    local INSTALL_DIR="$test_dir/install"  # Директория не создана
    
    # Вызываем тестируемую функцию, перенаправляя stderr, чтобы скрыть сообщение об ошибке cp
    _copy_installation_files 2>/dev/null
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Ошибка копирования файлов (директория назначения не существует)"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: копирование пустой директории
test_copy_installation_files_empty_source() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем пустую исходную директорию
    local source_dir="$test_dir/source"
    mkdir -p "$source_dir"
    
    # Переопределяем глобальные переменные для условий теста
    local TMP_LOCAL_RUNNER_PATH="$source_dir/some_runner.sh"
    local INSTALL_DIR="$test_dir/install"
    
    # Создаем директорию назначения
    mkdir -p "$INSTALL_DIR"
    
    # Вызываем тестируемую функцию, перенаправляя stderr, чтобы скрыть сообщение об ошибке cp
    _copy_installation_files 2>/dev/null
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Копирование пустой директории (должно завершиться с ошибкой)"
    
    # Проверяем, что директория назначения осталась пустой
    local file_count=$(find "$INSTALL_DIR" -type f | wc -l)
    if [[ "$file_count" -eq 0 ]]; then
        echo "[V] Директория назначения пуста"
    else
        echo "[X] Директория назначения не пуста: $file_count файлов"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: копирование с файлами специальных типов
test_copy_installation_files_special_files() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем исходную директорию с файлами
    local source_dir="$test_dir/source"
    mkdir -p "$source_dir"
    
    # Создаем тестовые файлы специальных типов
    touch "$source_dir/executable.sh"
    chmod +x "$source_dir/executable.sh"
    ln -s "executable.sh" "$source_dir/symlink.sh"
    
    # Переопределяем глобальные переменные для условий теста
    local TMP_LOCAL_RUNNER_PATH="$source_dir/some_runner.sh"
    local INSTALL_DIR="$test_dir/install"
    
    # Создаем директорию назначения
    mkdir -p "$INSTALL_DIR"
    
    # Вызываем тестируемую функцию
    _copy_installation_files
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Копирование файлов специальных типов"
    
    # Проверяем, что исполняемый файл скопирован с правами
    if [[ -x "$INSTALL_DIR/executable.sh" ]]; then
        echo "[V] Исполняемый файл скопирован с правами на выполнение"
    else
        echo "[X] Исполняемый файл скопирован без прав на выполнение"
    fi
    
    # Проверяем, что символическая ссылка скопирована
    if [[ -L "$INSTALL_DIR/symlink.sh" ]]; then
        echo "[V] Символическая ссылка скопирована"
    else
        echo "[X] Символическая ссылка не скопирована"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _copy_installation_files"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_copy_installation_files_success
    test_copy_installation_files_no_dest_dir
    test_copy_installation_files_empty_source
    test_copy_installation_files_special_files
    
    echo "============================================="
    echo "Тесты завершены"
fi