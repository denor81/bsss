#!/usr/bin/env bash
# tests/test_copy_installation_files.sh
# Тест для функции _copy_installation_files

# Подключаем тестируемый файл
# shellcheck source=../oneline-runner.sh
source "$(dirname "${BASH_SOURCE[0]}")/../oneline-runner.sh"
# Примечание: функции логирования уже определены в oneline-runner.sh

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
    
    # Создаем директорию назначения
    local install_dir="$test_dir/install"
    mkdir -p "$install_dir"
    
    # Вызываем тестируемую функцию с параметрами вместо переопределения readonly переменных
    _copy_installation_files "$source_dir" "$install_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное копирование файлов"
    
    # Проверяем, что файлы скопированы
    if [[ -f "$install_dir/file1.txt" ]]; then
        echo "[V] Файл file1.txt скопирован"
    else
        echo "[X] Файл file1.txt не скопирован"
    fi
    
    if [[ -f "$install_dir/file2.txt" ]]; then
        echo "[V] Файл file2.txt скопирован"
    else
        echo "[X] Файл file2.txt не скопирован"
    fi
    
    if [[ -f "$install_dir/subdir/file3.txt" ]]; then
        echo "[V] Файл subdir/file3.txt скопирован"
    else
        echo "[X] Файл subdir/file3.txt не скопирован"
    fi
    
    # Проверяем содержимое скопированных файлов
    local content1=$(cat "$install_dir/file1.txt")
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
    
    # Вызываем тестируемую функцию с параметрами, перенаправляя stderr, чтобы скрыть сообщение об ошибке cp
    _copy_installation_files "$source_dir" "$test_dir/install" 2>/dev/null
    
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
    
    # Создаем директорию назначения
    local install_dir="$test_dir/install"
    mkdir -p "$install_dir"
    
    # Вызываем тестируемую функцию с параметрами, перенаправляя stderr, чтобы скрыть сообщение об ошибке cp
    _copy_installation_files "$source_dir" "$install_dir" 2>/dev/null
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Копирование пустой директории (должно завершиться с ошибкой)"
    
    # Проверяем, что директория назначения осталась пустой
    local file_count=$(find "$install_dir" -type f | wc -l)
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
    
    # Создаем директорию назначения
    local install_dir="$test_dir/install"
    mkdir -p "$install_dir"
    
    # Вызываем тестируемую функцию с параметрами
    _copy_installation_files "$source_dir" "$install_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Копирование файлов специальных типов"
    
    # Проверяем, что исполняемый файл скопирован с правами
    if [[ -x "$install_dir/executable.sh" ]]; then
        echo "[V] Исполняемый файл скопирован с правами на выполнение"
    else
        echo "[X] Исполняемый файл скопирован без прав на выполнение"
    fi
    
    # Проверяем, что символическая ссылка скопирована
    if [[ -L "$install_dir/symlink.sh" ]]; then
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