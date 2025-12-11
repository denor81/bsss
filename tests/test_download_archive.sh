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
    
    # Вызываем тестируемую функцию с URL в качестве параметра
    _download_archive "file://$test_archive"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Загрузка с параметрами по умолчанию"
    
    # Проверяем, что TMPARCHIVE установлен и файл существует
    if [ -f "$TMPARCHIVE" ]; then
        echo "[V] Файл успешно загружен с параметрами по умолчанию"
        # Проверяем, что файл имеет ненулевой размер (содержит данные)
        local file_size=$(stat -c "%s" "$TMPARCHIVE" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 0 ]; then
            echo "[V] Загруженный файл имеет корректный размер"
        else
            echo "[X] Загруженный файл имеет нулевой размер"
        fi
    else
        echo "[X] Файл не загружен с параметрами по умолчанию"
    fi
    
    # Удаляем временные файлы
    rm -f "$TMPARCHIVE"
    rm -rf "$test_dir"
}

# Тест 4: проверка работы с указанным путем для сохранения
test_download_archive_specific_path() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local test_file="$test_dir/test.txt"
    local test_archive="$test_dir/test.tar.gz"
    
    # Создаем тестовый файл и архив
    echo "test content" > "$test_file"
    tar -czf "$test_archive" -C "$test_dir" test.txt
    
    # Создаем URL для файла
    local archive_url="file://$test_archive"
    
    # Вызываем тестируемую функцию с указанным путем для сохранения
    _download_archive "$archive_url" "$test_dir/downloaded.tar.gz" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Загрузка в указанный путь"
    
    # Проверяем, что файл загружен по указанному пути
    if [ -f "$test_dir/downloaded.tar.gz" ]; then
        echo "[V] Файл успешно загружен по указанному пути"
        # Проверяем, что файл имеет ненулевой размер (содержит данные)
        local file_size=$(stat -c "%s" "$test_dir/downloaded.tar.gz" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 0 ]; then
            echo "[V] Загруженный файл имеет корректный размер"
        else
            echo "[X] Загруженный файл имеет нулевой размер"
        fi
    else
        echo "[X] Файл не загружен по указанному пути"
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
        # Проверяем, что файл имеет ненулевой размер (содержит данные)
        local file_size=$(stat -c "%s" "$TMPARCHIVE" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 0 ]; then
            echo "[V] Загруженный файл имеет корректный размер"
        else
            echo "[X] Загруженный файл имеет нулевой размер"
        fi
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

# Тест 6: проверка обработки сетевых ошибок (неверный хост)
test_download_archive_network_error() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Используем несуществующий URL, который вызовет ошибку сети
    local invalid_url="http://nonexistent-host-12345.com/nonexistent.tar.gz"
    
    # Вызываем тестируемую функцию с невалидным URL
    _download_archive "$invalid_url" "$test_dir/downloaded.tar.gz" false
    
    # Проверяем, что функция вернула ошибку
    local result=$?
    assertEquals 1 $result "Обработка сетевой ошибки"
    
    # Проверяем, что файл не был создан
    if [ ! -f "$test_dir/downloaded.tar.gz" ]; then
        echo "[V] Файл не создан при сетевой ошибке"
    else
        echo "[X] Файл создан при сетевой ошибке"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 7: проверка обработки некорректного архива
test_download_archive_invalid_archive() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local invalid_archive="$test_dir/invalid.tar.gz"
    
    # Создаем некорректный файл архива (просто текстовый файл)
    echo "Это не архив, а просто текст" > "$invalid_archive"
    
    # Создаем URL для файла
    local archive_url="file://$invalid_archive"
    
    # Вызываем тестируемую функцию с некорректным архивом
    _download_archive "$archive_url" "$test_dir/downloaded.tar.gz" false
    
    # Проверяем результат (функция должна успешно скачать файл, даже если он некорректный)
    local result=$?
    assertEquals 0 $result "Загрузка некорректного архива"
    
    # Проверяем, что файл загружен
    if [ -f "$test_dir/downloaded.tar.gz" ]; then
        echo "[V] Некорректный файл успешно загружен"
        # Проверяем, что файл имеет ненулевой размер
        local file_size=$(stat -c "%s" "$test_dir/downloaded.tar.gz" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 0 ]; then
            echo "[V] Загруженный файл имеет корректный размер"
        else
            echo "[X] Загруженный файл имеет нулевой размер"
        fi
    else
        echo "[X] Некорректный файл не загружен"
    fi
    
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
    test_download_archive_specific_path
    test_download_archive_auto_tmpfile
    test_download_archive_network_error
    test_download_archive_invalid_archive
    
    echo "============================================="
    echo "Тесты завершены"
fi