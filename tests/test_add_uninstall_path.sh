#!/usr/bin/env bash
# tests/test_add_uninstall_path.sh
# Тест для функции _add_uninstall_path

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
# ТЕСТЫ ФУНКЦИИ _add_uninstall_path
# ==========================================

# Тест 1: успешное добавление пути в лог-файл
test_add_uninstall_path_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь для добавления в лог
    local test_path="/path/to/uninstall"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию с параметрами
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное добавление пути в лог"
    
    # Проверяем, что путь добавлен в файл
    if [[ -f "$install_log_path" ]]; then
        local found_path
        found_path=$(grep -Fxq "$test_path" "$install_log_path" 2>/dev/null && echo "found" || echo "not_found")
        assertEquals "found" "$found_path" "Путь найден в лог-файле"
    else
        echo "[X] Лог-файл не создан"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: попытка добавить дублирующийся путь
test_add_uninstall_path_duplicate() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь для добавления в лог
    local test_path="/path/to/uninstall"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Создаем лог-файл и добавляем путь вручную
    echo "$test_path" > "$install_log_path"
    
    # Проверяем, что путь уже в файле
    local initial_count
    initial_count=$(grep -c "$test_path" "$install_log_path" 2>/dev/null || echo "0")
    assertEquals 1 "$initial_count" "Путь уже существует в лог-файле"
    
    # Вызываем тестируемую функцию с тем же путем
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Обработка дублирующегося пути"
    
    # Проверяем, что путь не был добавлен повторно
    local final_count
    final_count=$(grep -c "$test_path" "$install_log_path" 2>/dev/null || echo "0")
    assertEquals 1 "$final_count" "Путь не дублирован в лог-файле"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: добавление нескольких путей
test_add_uninstall_path_multiple() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Пути для добавления в лог
    local test_path1="/path/to/uninstall1"
    local test_path2="/path/to/uninstall2"
    local test_path3="/path/to/uninstall3"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию для каждого пути
    _add_uninstall_path "$test_path1" "$install_log_path"
    local result1=$?
    assertEquals 0 $result1 "Добавление первого пути"
    
    _add_uninstall_path "$test_path2" "$install_log_path"
    local result2=$?
    assertEquals 0 $result2 "Добавление второго пути"
    
    _add_uninstall_path "$test_path3" "$install_log_path"
    local result3=$?
    assertEquals 0 $result3 "Добавление третьего пути"
    
    # Проверяем, что все пути добавлены в файл
    if [[ -f "$install_log_path" ]]; then
        local line_count
        line_count=$(wc -l < "$install_log_path" 2>/dev/null || echo "0")
        assertEquals 3 "$line_count" "Количество путей в лог-файле"
        
        # Проверяем каждый путь
        local found1
        found1=$(grep -Fxq "$test_path1" "$install_log_path" 2>/dev/null && echo "found" || echo "not_found")
        assertEquals "found" "$found1" "Первый путь найден в лог-файле"
        
        local found2
        found2=$(grep -Fxq "$test_path2" "$install_log_path" 2>/dev/null && echo "found" || echo "not_found")
        assertEquals "found" "$found2" "Второй путь найден в лог-файле"
        
        local found3
        found3=$(grep -Fxq "$test_path3" "$install_log_path" 2>/dev/null && echo "found" || echo "not_found")
        assertEquals "found" "$found3" "Третий путь найден в лог-файле"
    else
        echo "[X] Лог-файл не создан"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: добавление пути с пробелами
test_add_uninstall_path_with_spaces() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь с пробелами для добавления в лог
    local test_path="/path/with spaces/to/uninstall"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное добавление пути с пробелами в лог"
    
    # Проверяем, что путь добавлен в файл
    if [[ -f "$install_log_path" ]]; then
        local found_path
        found_path=$(grep -Fxq "$test_path" "$install_log_path" 2>/dev/null && echo "found" || echo "not_found")
        assertEquals "found" "$found_path" "Путь с пробелами найден в лог-файле"
    else
        echo "[X] Лог-файл не создан"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: добавление пустого пути
test_add_uninstall_path_empty() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Пустой путь для добавления в лог
    local test_path=""
    
    # Вызываем тестируемую функцию
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Обработка пустого пути (должна быть ошибка)"
    
    # Проверяем, что пустая строка не добавлена в файл
    if [[ -f "$install_log_path" ]]; then
        local found_path
        found_path=$(grep -Fxq "$test_path" "$install_log_path" 2>/dev/null && echo "found" || echo "not_found")
        assertEquals "not_found" "$found_path" "Пустая строка не найдена в лог-файле"
    else
        echo "[V] Лог-файл не создан (как и ожидалось)"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _add_uninstall_path"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_add_uninstall_path_success
    test_add_uninstall_path_duplicate
    test_add_uninstall_path_multiple
    test_add_uninstall_path_with_spaces
    test_add_uninstall_path_empty
    
    echo "============================================="
    echo "Тесты завершены"
fi