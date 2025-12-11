#!/usr/bin/env bash
# tests/test_set_execution_permissions.sh
# Тест для функции _set_execution_permissions

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
# ТЕСТЫ ФУНКЦИИ _set_execution_permissions
# ==========================================

# Тест 1: успешная установка прав на выполнение для .sh файлов
test_set_execution_permissions_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовые .sh файлы без прав на выполнение
    echo "#!/bin/bash" > "$test_dir/script1.sh"
    echo "#!/bin/bash" > "$test_dir/script2.sh"
    echo "test content" > "$test_dir/file.txt"  # Не .sh файл
    
    # Убираем права на выполнение у .sh файлов
    chmod -x "$test_dir"/*.sh
    
    # Проверяем, что файлы не имеют прав на выполнение
    if [[ ! -x "$test_dir/script1.sh" ]]; then
        echo "[V] script1.sh не имеет прав на выполнение до вызова функции"
    else
        echo "[X] script1.sh уже имеет права на выполнение до вызова функции"
    fi
    
    # Вызываем тестируемую функцию с параметром вместо переопределения readonly переменной
    _set_execution_permissions "$test_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешная установка прав на выполнение"
    
    # Проверяем, что .sh файлы теперь имеют права на выполнение
    if [[ -x "$test_dir/script1.sh" ]]; then
        echo "[V] script1.sh имеет права на выполнение после вызова функции"
    else
        echo "[X] script1.sh не имеет прав на выполнение после вызова функции"
    fi
    
    if [[ -x "$test_dir/script2.sh" ]]; then
        echo "[V] script2.sh имеет права на выполнение после вызова функции"
    else
        echo "[X] script2.sh не имеет прав на выполнение после вызова функции"
    fi
    
    # Проверяем, что не .sh файл не изменил своих прав
    if [[ ! -x "$test_dir/file.txt" ]]; then
        echo "[V] file.txt не имеет прав на выполнение (как и ожидалось)"
    else
        echo "[X] file.txt имеет права на выполнение (неожиданно)"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: директория без .sh файлов
test_set_execution_permissions_no_sh_files() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем файлы не .sh расширения
    echo "test content 1" > "$test_dir/file1.txt"
    echo "test content 2" > "$test_dir/file2.conf"
    mkdir -p "$test_dir/subdir"
    echo "test content 3" > "$test_dir/subdir/file3.log"
    
    # Вызываем тестируемую функцию с параметром
    _set_execution_permissions "$test_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Директория без .sh файлов"
    
    # Проверяем, что файлы не имеют прав на выполнение
    if [[ ! -x "$test_dir/file1.txt" ]]; then
        echo "[V] file1.txt не имеет прав на выполнение"
    else
        echo "[X] file1.txt имеет права на выполнение"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: пустая директория
test_set_execution_permissions_empty_dir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию с параметром
    _set_execution_permissions "$test_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Пустая директория"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: директория с файлами, которые уже имеют права на выполнение
test_set_execution_permissions_already_executable() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовые .sh файлы с правами на выполнение
    echo "#!/bin/bash" > "$test_dir/script1.sh"
    echo "#!/bin/bash" > "$test_dir/script2.sh"
    chmod +x "$test_dir"/*.sh
    
    # Проверяем, что файлы уже имеют права на выполнение
    if [[ -x "$test_dir/script1.sh" ]]; then
        echo "[V] script1.sh уже имеет права на выполнение перед вызовом функции"
    else
        echo "[X] script1.sh не имеет прав на выполнение перед вызовом функции"
    fi
    
    # Вызываем тестируемую функцию с параметром
    _set_execution_permissions "$test_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файлы уже имеют права на выполнение"
    
    # Проверяем, что .sh файлы все еще имеют права на выполнение
    if [[ -x "$test_dir/script1.sh" ]]; then
        echo "[V] script1.sh все еще имеет права на выполнение после вызова функции"
    else
        echo "[X] script1.sh не имеет прав на выполнение после вызова функции"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: директория не существует
test_set_execution_permissions_dir_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local nonexistent_path="$test_dir/nonexistent"
    
    # Вызываем тестируемую функцию с параметром
    _set_execution_permissions "$nonexistent_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Директория не существует"
    
    # Проверяем, что директория действительно не была создана
    if [[ ! -d "$nonexistent_path" ]]; then
        echo "[V] Директория не была создана после вызова функции"
    else
        echo "[X] Директория была создана после вызова функции"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 6: файлы в поддиректориях
test_set_execution_permissions_subdirectories() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем структуру с поддиректориями
    mkdir -p "$test_dir/subdir1"
    mkdir -p "$test_dir/subdir2"
    
    # Создаем .sh файлы в разных директориях
    echo "#!/bin/bash" > "$test_dir/script.sh"
    echo "#!/bin/bash" > "$test_dir/subdir1/subscript1.sh"
    echo "#!/bin/bash" > "$test_dir/subdir2/subscript2.sh"
    echo "test content" > "$test_dir/subdir1/file.txt"
    
    # Убираем права на выполнение у .sh файлов
    chmod -x "$test_dir/script.sh"
    chmod -x "$test_dir/subdir1/subscript1.sh"
    chmod -x "$test_dir/subdir2/subscript2.sh"
    
    # Вызываем тестируемую функцию с параметром
    _set_execution_permissions "$test_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файлы в поддиректориях"
    
    # Проверяем, что только файл в корневой директории получил права на выполнение
    if [[ -x "$test_dir/script.sh" ]]; then
        echo "[V] script.sh в корневой директории имеет права на выполнение"
    else
        echo "[X] script.sh в корневой директории не имеет прав на выполнение"
    fi
    
    # Проверяем, что файлы в поддиректориях не получили права на выполнение
    if [[ ! -x "$test_dir/subdir1/subscript1.sh" ]]; then
        echo "[V] subscript1.sh в поддиректории не имеет прав на выполнение"
    else
        echo "[X] subscript1.sh в поддиректории имеет права на выполнение"
    fi
    
    if [[ ! -x "$test_dir/subdir2/subscript2.sh" ]]; then
        echo "[V] subscript2.sh в поддиректории не имеет прав на выполнение"
    else
        echo "[X] subscript2.sh в поддиректории имеет права на выполнение"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 7: файлы без расширения
test_set_execution_permissions_no_extension() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем файлы с разными расширениями и без расширения
    echo "#!/bin/bash" > "$test_dir/script"
    echo "#!/bin/bash" > "$test_dir/script.sh"
    echo "#!/bin/bash" > "$test_dir/script.bash"
    echo "#!/bin/bash" > "$test_dir/.hidden.sh"
    
    # Убираем права на выполнение у всех файлов
    chmod -x "$test_dir"/*
    
    # Вызываем тестируемую функцию с параметром
    _set_execution_permissions "$test_dir"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файлы без расширения"
    
    # Проверяем, что только .sh файлы получили права на выполнение
    if [[ -x "$test_dir/script.sh" ]]; then
        echo "[V] script.sh имеет права на выполнение"
    else
        echo "[X] script.sh не имеет прав на выполнение"
    fi
    
    if [[ ! -x "$test_dir/.hidden.sh" ]]; then
        echo "[V] .hidden.sh не имеет прав на выполнение (скрытые файлы не обрабатываются)"
    else
        echo "[X] .hidden.sh имеет права на выполнение (неожиданно)"
    fi
    
    # Проверяем, что файлы без расширения .sh не получили права на выполнение
    if [[ ! -x "$test_dir/script" ]]; then
        echo "[V] script (без расширения) не имеет прав на выполнение"
    else
        echo "[X] script (без расширения) имеет права на выполнение"
    fi
    
    if [[ ! -x "$test_dir/script.bash" ]]; then
        echo "[V] script.bash (не .sh расширение) не имеет прав на выполнение"
    else
        echo "[X] script.bash (не .sh расширение) имеет права на выполнение"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
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
        test_set_execution_permissions_success || test_result=1
        test_set_execution_permissions_no_sh_files || test_result=1
        test_set_execution_permissions_empty_dir || test_result=1
        test_set_execution_permissions_already_executable || test_result=1
        test_set_execution_permissions_dir_not_exists || test_result=1
        test_set_execution_permissions_subdirectories || test_result=1
        test_set_execution_permissions_no_extension || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _set_execution_permissions"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_set_execution_permissions_success
            test_set_execution_permissions_no_sh_files
            test_set_execution_permissions_empty_dir
            test_set_execution_permissions_already_executable
            test_set_execution_permissions_dir_not_exists
            test_set_execution_permissions_subdirectories
            test_set_execution_permissions_no_extension
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _set_execution_permissions"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_set_execution_permissions_success
        test_set_execution_permissions_no_sh_files
        test_set_execution_permissions_empty_dir
        test_set_execution_permissions_already_executable
        test_set_execution_permissions_dir_not_exists
        test_set_execution_permissions_subdirectories
        test_set_execution_permissions_no_extension
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi