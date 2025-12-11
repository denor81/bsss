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

# Вспомогательная функция для проверки существования файла
assertFileExists() {
    local file_path="$1"
    local message="$2"
    
    if [[ -f "$file_path" ]]; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message - файл не существует"
        return 1
    fi
}

# Вспомогательная функция для проверки прав доступа файла
assertFileExecutable() {
    local file_path="$1"
    local message="$2"
    
    if [[ -x "$file_path" ]]; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message - файл не является исполняемым"
        return 1
    fi
}

# Вспомогательная функция для проверки символической ссылки
assertSymlinkExists() {
    local symlink_path="$1"
    local message="$2"
    
    if [[ -L "$symlink_path" ]]; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message - символическая ссылка не существует"
        return 1
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
    
    # Вызываем тестируемую функцию с параметрами
    _copy_installation_files "$source_dir" "$install_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное копирование файлов"
    
    # Проверяем, что файлы скопированы (фокус на поведении, а не на содержимом)
    assertFileExists "$install_dir/file1.txt" "Файл file1.txt скопирован"
    assertFileExists "$install_dir/file2.txt" "Файл file2.txt скопирован"
    assertFileExists "$install_dir/subdir/file3.txt" "Файл subdir/file3.txt скопирован"
    
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
    
    # Вызываем тестируемую функцию с параметрами
    _copy_installation_files "$source_dir" "$install_dir" 2>/dev/null
    
    # Проверяем результат (функция возвращает ошибку при копировании пустой директории)
    local result=$?
    assertEquals 1 $result "Копирование пустой директории (завершается с ошибкой)"
    
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
    assertFileExecutable "$install_dir/executable.sh" "Исполняемый файл скопирован с правами на выполнение"
    
    # Проверяем, что символическая ссылка скопирована
    assertSymlinkExists "$install_dir/symlink.sh" "Символическая ссылка скопирована"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: копирование файлов с пробелами в именах
test_copy_installation_files_with_spaces() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем исходную директорию с файлами
    local source_dir="$test_dir/source"
    mkdir -p "$source_dir"
    
    # Создаем файлы с пробелами в именах
    echo "content with spaces" > "$source_dir/file with spaces.txt"
    mkdir -p "$source_dir/dir with spaces"
    echo "content in dir with spaces" > "$source_dir/dir with spaces/nested file.txt"
    
    # Создаем директорию назначения
    local install_dir="$test_dir/install"
    mkdir -p "$install_dir"
    
    # Вызываем тестируемую функцию с параметрами
    _copy_installation_files "$source_dir" "$install_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Копирование файлов с пробелами в именах"
    
    # Проверяем, что файлы с пробелами скопированы
    assertFileExists "$install_dir/file with spaces.txt" "Файл с пробелами в имени скопирован"
    assertFileExists "$install_dir/dir with spaces/nested file.txt" "Вложенный файл в директории с пробелами скопирован"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 6: копирование файлов с особыми правами доступа
test_copy_installation_files_special_permissions() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем исходную директорию с файлами
    local source_dir="$test_dir/source"
    mkdir -p "$source_dir"
    
    # Создаем файлы с особыми правами доступа
    touch "$source_dir/readonly.txt"
    chmod 444 "$source_dir/readonly.txt"  # Только для чтения
    touch "$source_dir/noexec.sh"
    chmod 644 "$source_dir/noexec.sh"  # Не исполняемый .sh файл
    
    # Создаем директорию назначения
    local install_dir="$test_dir/install"
    mkdir -p "$install_dir"
    
    # Вызываем тестируемую функцию с параметрами
    _copy_installation_files "$source_dir" "$install_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Копирование файлов с особыми правами доступа"
    
    # Проверяем, что файлы скопированы
    assertFileExists "$install_dir/readonly.txt" "Файл только для чтения скопирован"
    assertFileExists "$install_dir/noexec.sh" "Неисполняемый .sh файл скопирован"
    
    # Проверяем, что права доступа сохранены
    local readonly_perms=$(stat -c "%a" "$install_dir/readonly.txt")
    assertEquals "444" "$readonly_perms" "Права доступа файла только для чтения сохранены"
    
    local noexec_perms=$(stat -c "%a" "$install_dir/noexec.sh")
    assertEquals "644" "$noexec_perms" "Права доступа неисполняемого .sh файла сохранены"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 7: копирование больших файлов
test_copy_installation_files_large_files() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем исходную директорию с файлами
    local source_dir="$test_dir/source"
    mkdir -p "$source_dir"
    
    # Создаем большой файл (1MB)
    dd if=/dev/zero of="$source_dir/large_file.bin" bs=1024 count=1024 2>/dev/null
    
    # Создаем директорию назначения
    local install_dir="$test_dir/install"
    mkdir -p "$install_dir"
    
    # Вызываем тестируемую функцию с параметрами
    _copy_installation_files "$source_dir" "$install_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Копирование больших файлов"
    
    # Проверяем, что большой файл скопирован
    assertFileExists "$install_dir/large_file.bin" "Большой файл скопирован"
    
    # Проверяем, что размер файла совпадает
    local source_size=$(stat -c "%s" "$source_dir/large_file.bin")
    local dest_size=$(stat -c "%s" "$install_dir/large_file.bin")
    assertEquals "$source_size" "$dest_size" "Размер большого файла совпадает"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 8: копирование с несуществующей исходной директорией
test_copy_installation_files_no_source_dir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем директорию назначения
    local install_dir="$test_dir/install"
    mkdir -p "$install_dir"
    
    # Вызываем тестируемую функцию с несуществующей исходной директорией
    _copy_installation_files "$test_dir/nonexistent" "$install_dir" 2>/dev/null
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Ошибка копирования файлов (исходная директория не существует)"
    
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
    test_copy_installation_files_with_spaces
    test_copy_installation_files_special_permissions
    test_copy_installation_files_large_files
    test_copy_installation_files_no_source_dir
    
    echo "============================================="
    echo "Тесты завершены"
fi