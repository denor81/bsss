#!/usr/bin/env bash
# tests/test_run_uninstall_testable.sh
# Тест для функции _run_uninstall_testable

# Подключаем тестируемый файл
# shellcheck source=../lib/uninstall_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/uninstall_functions.sh"

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

# Мокируем функции логирования, чтобы избежать вывода
log_error() {
    : # Ничего не делаем, подавляем вывод
}

log_info() {
    : # Ничего не делаем, подавляем вывод
}

log_success() {
    : # Ничего не делаем, подавляем вывод
}

# Функция для очистки временных ресурсов
cleanup_test_resources() {
    local test_dir="$1"
    if [[ -n "$test_dir" && -d "$test_dir" ]]; then
        rm -rf "$test_dir"
    fi
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
# ТЕСТЫ ФУНКЦИИ _run_uninstall_testable
# ==========================================

# Тест 1: успешное удаление с авто-подтверждением
test_run_uninstall_testable_auto_confirm_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовые файлы и директории
    touch "$test_dir/test_file1"
    touch "$test_dir/test_file2"
    mkdir -p "$test_dir/test_dir"
    touch "$test_dir/test_dir/test_file3"
    
    # Создаем файл со списком путей для удаления
    local uninstall_paths_file="$test_dir/uninstall_paths.txt"
    echo "$test_dir/test_file1" > "$uninstall_paths_file"
    echo "$test_dir/test_file2" >> "$uninstall_paths_file"
    echo "$test_dir/test_dir" >> "$uninstall_paths_file"
    echo "$test_dir/nonexistent_path" >> "$uninstall_paths_file"
    
    # Вызываем тестируемую функцию с параметрами
    _run_uninstall_testable "$uninstall_paths_file" "test_util" "test_module" "true"
    
    # Проверяем результат
    local function_result=$?
    assertEquals 0 $function_result "Успешное удаление с авто-подтверждением"
    
    # Проверяем, что файлы и директории удалены
    local result=0
    if [[ -e "$test_dir/test_file1" || -e "$test_dir/test_file2" || -e "$test_dir/test_dir" ]]; then
        echo "[X] Файлы или директории не были удалены"
        result=1
    else
        echo "[V] Файлы и директории успешно удалены"
    fi
    
    # Удаляем временную директорию
    cleanup_test_resources "$test_dir"
}

# Тест 2: успешное удаление с подтверждением пользователя
test_run_uninstall_testable_user_confirm_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл
    touch "$test_dir/test_file"
    
    # Создаем файл со списком путей для удаления
    local uninstall_paths_file="$test_dir/uninstall_paths.txt"
    echo "$test_dir/test_file" > "$uninstall_paths_file"
    
    # Вызываем тестируемую функцию с параметрами, перенаправляя ввод
    echo "y" | _run_uninstall_testable "$uninstall_paths_file" "test_util" "test_module" "false"
    
    # Проверяем результат
    local function_result=$?
    assertEquals 0 $function_result "Успешное удаление с подтверждением пользователя"
    
    # Проверяем, что файл удален
    local result=0
    if [[ -e "$test_dir/test_file" ]]; then
        echo "[X] Файл не был удален"
        result=1
    else
        echo "[V] Файл успешно удален"
    fi
    
    # Удаляем временную директорию
    cleanup_test_resources "$test_dir"
}

# Тест 3: отмена удаления пользователем
test_run_uninstall_testable_user_cancel() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл
    touch "$test_dir/test_file"
    
    # Создаем файл со списком путей для удаления
    local uninstall_paths_file="$test_dir/uninstall_paths.txt"
    echo "$test_dir/test_file" > "$uninstall_paths_file"
    
    # Вызываем тестируемую функцию с параметрами, перенаправляя ввод
    echo "n" | _run_uninstall_testable "$uninstall_paths_file" "test_util" "test_module" "false"
    
    # Проверяем результат
    local function_result=$?
    assertEquals 0 $function_result "Отмена удаления пользователем"
    
    # Проверяем, что файл не удален
    local result=0
    if [[ -e "$test_dir/test_file" ]]; then
        echo "[V] Файл не был удален (как ожидалось)"
    else
        echo "[X] Файл был удален вопреки отмене"
        result=1
    fi
    
    # Удаляем временную директорию
    cleanup_test_resources "$test_dir"
}

# Тест 4: файл со списком путей не существует
test_run_uninstall_testable_missing_file() {
    # Вызываем тестируемую функцию с несуществующим файлом
    _run_uninstall_testable "/nonexistent/path/uninstall.txt" "test_util" "test_module" "true"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Файл со списком путей не существует"
}

# Тест 5: удаление символической ссылки
test_run_uninstall_testable_symlink() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл и символическую ссылку
    touch "$test_dir/test_file"
    ln -s "$test_dir/test_file" "$test_dir/test_symlink"
    
    # Создаем файл со списком путей для удаления
    local uninstall_paths_file="$test_dir/uninstall_paths.txt"
    echo "$test_dir/test_symlink" > "$uninstall_paths_file"
    
    # Вызываем тестируемую функцию с параметрами
    _run_uninstall_testable "$uninstall_paths_file" "test_util" "test_module" "true"
    
    # Проверяем результат
    local function_result=$?
    assertEquals 0 $function_result "Удаление символической ссылки"
    
    # Проверяем, что символическая ссылка удалена, но файл остался
    local result=0
    if [[ -L "$test_dir/test_symlink" ]]; then
        echo "[X] Символическая ссылка не была удалена"
        result=1
    else
        echo "[V] Символическая ссылка успешно удалена"
    fi
    
    if [[ -e "$test_dir/test_file" ]]; then
        echo "[V] Исходный файл остался нетронутым"
    else
        echo "[X] Исходный файл был удален"
        result=1
    fi
    
    # Удаляем временную директорию
    cleanup_test_resources "$test_dir"
}

# Тест 6: удаление путей с пробелами и специальными символами
test_run_uninstall_testable_special_paths() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовые файлы с особыми именами
    touch "$test_dir/file with spaces.txt"
    touch "$test_dir/file'with'quotes.txt"
    touch "$test_dir/file\$with\$dollar.txt"
    mkdir -p "$test_dir/dir with spaces"
    touch "$test_dir/dir with spaces/file.txt"
    
    # Создаем файл со списком путей для удаления
    local uninstall_paths_file="$test_dir/uninstall_paths.txt"
    echo "$test_dir/file with spaces.txt" > "$uninstall_paths_file"
    echo "$test_dir/file'with'quotes.txt" >> "$uninstall_paths_file"
    echo "$test_dir/file\$with\$dollar.txt" >> "$uninstall_paths_file"
    echo "$test_dir/dir with spaces" >> "$uninstall_paths_file"
    
    # Вызываем тестируемую функцию с параметрами
    _run_uninstall_testable "$uninstall_paths_file" "test_util" "test_module" "true"
    
    # Проверяем результат
    local function_result=$?
    assertEquals 0 $function_result "Удаление путей с пробелами и специальными символами"
    
    # Проверяем, что файлы и директории удалены
    local result=0
    if [[ -e "$test_dir/file with spaces.txt" || -e "$test_dir/file'with'quotes.txt" || -e "$test_dir/file\$with\$dollar.txt" || -e "$test_dir/dir with spaces" ]]; then
        echo "[X] Файлы или директории с особыми именами не были удалены"
        result=1
    else
        echo "[V] Файлы и директории с особыми именами успешно удалены"
    fi
    
    # Удаляем временную директорию
    cleanup_test_resources "$test_dir"
}

# Тест 7: обработка пустых строк в файле путей
test_run_uninstall_testable_empty_lines() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл
    touch "$test_dir/test_file"
    
    # Создаем файл со списком путей для удаления с пустыми строками
    local uninstall_paths_file="$test_dir/uninstall_paths.txt"
    echo "" > "$uninstall_paths_file"
    echo "$test_dir/test_file" >> "$uninstall_paths_file"
    echo "" >> "$uninstall_paths_file"
    echo "   " >> "$uninstall_paths_file"
    
    # Вызываем тестируемую функцию с параметрами
    _run_uninstall_testable "$uninstall_paths_file" "test_util" "test_module" "true"
    
    # Проверяем результат
    local function_result=$?
    assertEquals 0 $function_result "Обработка пустых строк в файле путей"
    
    # Проверяем, что файл удален
    local result=0
    if [[ -e "$test_dir/test_file" ]]; then
        echo "[X] Файл не был удален"
        result=1
    else
        echo "[V] Файл успешно удален"
    fi
    
    # Удаляем временную директорию
    cleanup_test_resources "$test_dir"
}

# Тест 8: обработка несуществующих путей в файле
test_run_uninstall_testable_nonexistent_paths() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый файл
    touch "$test_dir/test_file"
    
    # Создаем файл со списком путей для удаления, включая несуществующие
    local uninstall_paths_file="$test_dir/uninstall_paths.txt"
    echo "$test_dir/test_file" > "$uninstall_paths_file"
    echo "/nonexistent/path1" >> "$uninstall_paths_file"
    echo "/nonexistent/path2" >> "$uninstall_paths_file"
    
    # Вызываем тестируемую функцию с параметрами
    _run_uninstall_testable "$uninstall_paths_file" "test_util" "test_module" "true"
    
    # Проверяем результат - функция должна завершиться успешно
    local function_result=$?
    # Ожидаем успех, так как функция должна обрабатывать несуществующие пути корректно
    assertEquals 0 $function_result "Обработка несуществующих путей в файле"
    
    # Проверяем, что существующий файл был удален
    local result=0
    if [[ -e "$test_dir/test_file" ]]; then
        echo "[X] Существующий файл не был удален"
        result=1
    else
        echo "[V] Существующий файл был удален"
    fi
    
    # Удаляем временную директорию
    cleanup_test_resources "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Проверяем, запущен ли тест через раннер
    if [[ "${TEST_RUNNER_MODE:-}" == "1" ]]; then
        # Режим работы через раннер - выводим только в случае ошибок
        test_output=""
        test_result=0
        
        # Запускаем тесты и захватываем вывод
        test_run_uninstall_testable_auto_confirm_success || test_result=1
        test_run_uninstall_testable_user_confirm_success || test_result=1
        test_run_uninstall_testable_user_cancel || test_result=1
        test_run_uninstall_testable_missing_file || test_result=1
        test_run_uninstall_testable_symlink || test_result=1
        test_run_uninstall_testable_special_paths || test_result=1
        test_run_uninstall_testable_empty_lines || test_result=1
        test_run_uninstall_testable_nonexistent_paths || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _run_uninstall_testable"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_run_uninstall_testable_auto_confirm_success
            test_run_uninstall_testable_user_confirm_success
            test_run_uninstall_testable_user_cancel
            test_run_uninstall_testable_missing_file
            test_run_uninstall_testable_symlink
            test_run_uninstall_testable_special_paths
            test_run_uninstall_testable_empty_lines
            test_run_uninstall_testable_nonexistent_paths
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _run_uninstall_testable"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_run_uninstall_testable_auto_confirm_success
        test_run_uninstall_testable_user_confirm_success
        test_run_uninstall_testable_user_cancel
        test_run_uninstall_testable_missing_file
        test_run_uninstall_testable_symlink
        test_run_uninstall_testable_special_paths
        test_run_uninstall_testable_empty_lines
        test_run_uninstall_testable_nonexistent_paths
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi