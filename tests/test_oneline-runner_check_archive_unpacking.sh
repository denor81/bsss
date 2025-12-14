#!/usr/bin/env bash
# tests/test_check_archive_unpacking.sh
# Тест для функции _check_archive_unpacking

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

# Вспомогательная функция для проверки содержимого переменной
assertVariableEquals() {
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

# Вспомогательная функция для создания тестовой структуры
create_test_structure() {
    local test_dir="$1"
    local file_name="$2"
    local subdir="$3"
    
    # Создаем поддиректорию если указана
    if [ -n "$subdir" ]; then
        mkdir -p "$test_dir/$subdir"
        touch "$test_dir/$subdir/$file_name"
        echo "$test_dir/$subdir/$file_name"
    else
        touch "$test_dir/$file_name"
        echo "$test_dir/$file_name"
    fi
}

# ==========================================
# ТЕСТЫ ФУНКЦИИ _check_archive_unpacking
# ==========================================

# Тест 1: когда искомый файл существует в корневой директории
test_check_archive_unpacking_file_exists_in_root() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local file_name="test-runner.sh"
    
    # Создаем искомый файл в директории
    create_test_structure "$test_dir" "$file_name" ""
    
    # Сбрасываем глобальную переменную перед тестом
    unset TMP_LOCAL_RUNNER_PATH
    
    # Вызываем тестируемую функцию с параметрами
    _check_archive_unpacking "$test_dir" "$file_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файл существует в корневой директории"
    
    # Проверяем, что глобальная переменная установлена правильно
    assertVariableEquals "$test_dir/$file_name" "$TMP_LOCAL_RUNNER_PATH" "Путь к файлу установлен корректно"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда искомый файл существует в поддиректории
test_check_archive_unpacking_file_exists_in_subdir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local file_name="test-runner.sh"
    local subdir="subdir"
    
    # Создаем искомый файл в поддиректории
    create_test_structure "$test_dir" "$file_name" "$subdir"
    
    # Сбрасываем глобальную переменную перед тестом
    unset TMP_LOCAL_RUNNER_PATH
    
    # Вызываем тестируемую функцию с параметрами
    _check_archive_unpacking "$test_dir" "$file_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файл существует в поддиректории"
    
    # Проверяем, что глобальная переменная установлена правильно
    assertVariableEquals "$test_dir/$subdir/$file_name" "$TMP_LOCAL_RUNNER_PATH" "Путь к файлу в поддиректории установлен корректно"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: когда искомый файл не существует
test_check_archive_unpacking_file_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local file_name="nonexistent-file.sh"
    
    # Создаем другой файл, но не искомый
    touch "$test_dir/another-file.sh"
    
    # Сбрасываем глобальную переменную перед тестом
    unset TMP_LOCAL_RUNNER_PATH
    
    # Вызываем тестируемую функцию с параметрами
    _check_archive_unpacking "$test_dir" "$file_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Файл не существует"
    
    # Проверяем, что глобальная переменная не установлена
    assertVariableEquals "" "$TMP_LOCAL_RUNNER_PATH" "Переменная TMP_LOCAL_RUNNER_PATH не установлена"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: когда директория пуста
test_check_archive_unpacking_empty_dir() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local file_name="test-runner.sh"
    
    # Директория остается пустой
    
    # Сбрасываем глобальную переменную перед тестом
    unset TMP_LOCAL_RUNNER_PATH
    
    # Вызываем тестируемую функцию с параметрами
    _check_archive_unpacking "$test_dir" "$file_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Пустая директория"
    
    # Проверяем, что глобальная переменная не установлена
    assertVariableEquals "" "$TMP_LOCAL_RUNNER_PATH" "Переменная TMP_LOCAL_RUNNER_PATH не установлена для пустой директории"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: проверка работы с третьим параметром (прямой путь к файлу)
test_check_archive_unpacking_with_path_param() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local file_name="test-runner.sh"
    local subdir="subdir"
    
    # Создаем искомый файл в поддиректории
    local expected_path=$(create_test_structure "$test_dir" "$file_name" "$subdir")
    
    # Сбрасываем глобальную переменную перед тестом
    unset TMP_LOCAL_RUNNER_PATH
    
    # Вызываем тестируемую функцию с прямым путем к файлу
    _check_archive_unpacking "$test_dir" "$file_name" "$expected_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файл найден по прямому пути"
    
    # Проверяем, что глобальная переменная установлена правильно
    assertVariableEquals "$expected_path" "$TMP_LOCAL_RUNNER_PATH" "Прямой путь к файлу установлен корректно"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 6: когда указан прямой путь к файлу (даже несуществующий)
test_check_archive_unpacking_with_invalid_path_param() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local file_name="test-runner.sh"
    local direct_path="/some/path/to/$file_name"
    
    # Сбрасываем глобальную переменную перед тестом
    unset TMP_LOCAL_RUNNER_PATH
    
    # Вызываем тестируемую функцию с прямым путем к файлу
    _check_archive_unpacking "$test_dir" "$file_name" "$direct_path"
    
    # Проверяем результат (функция вернет успех, если путь не пустой)
    local result=$?
    assertEquals 0 $result "Прямой путь к файлу (даже несуществующий)"
    
    # Проверяем, что глобальная переменная установлена с указанным путем
    assertVariableEquals "$direct_path" "$TMP_LOCAL_RUNNER_PATH" "Прямой путь к файлу установлен в переменную"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 7: проверка работы с файлами с похожими именами
test_check_archive_unpacking_similar_filenames() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local file_name="runner.sh"
    local similar_file="test-runner.sh"
    
    # Создаем файл с похожим именем, но не искомый
    touch "$test_dir/$similar_file"
    
    # Сбрасываем глобальную переменную перед тестом
    unset TMP_LOCAL_RUNNER_PATH
    
    # Вызываем тестируемую функцию
    _check_archive_unpacking "$test_dir" "$file_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Файл с точным именем не найден"
    
    # Проверяем, что глобальная переменная не установлена
    assertVariableEquals "" "$TMP_LOCAL_RUNNER_PATH" "Переменная TMP_LOCAL_RUNNER_PATH не установлена для файла с похожим именем"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 8: проверка работы с файлами в нескольких поддиректориях
test_check_archive_unpacking_multiple_subdirs() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local file_name="test-runner.sh"
    
    # Создаем несколько поддиректорий с файлами
    mkdir -p "$test_dir/subdir1"
    mkdir -p "$test_dir/subdir2"
    touch "$test_dir/subdir1/$file_name"
    touch "$test_dir/subdir2/$file_name"
    
    # Сбрасываем глобальную переменную перед тестом
    unset TMP_LOCAL_RUNNER_PATH
    
    # Вызываем тестируемую функцию
    _check_archive_unpacking "$test_dir" "$file_name"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файл найден в нескольких поддиректориях"
    
    # Проверяем, что глобальная переменная установлена (find найдет все файлы)
    # Ожидаем, что TMP_LOCAL_RUNNER_PATH содержит пути к обоим файлам
    local expected_pattern1="$test_dir/subdir1/$file_name"
    local expected_pattern2="$test_dir/subdir2/$file_name"
    
    # Проверяем, что переменная содержит оба пути (разделенных новой строкой)
    if [[ "$TMP_LOCAL_RUNNER_PATH" == *"$expected_pattern1"* ]] && [[ "$TMP_LOCAL_RUNNER_PATH" == *"$expected_pattern2"* ]]; then
        echo "[V] Пути к найденным файлам установлены корректно [$TMP_LOCAL_RUNNER_PATH]"
    else
        echo "[X] Пути к найденным файлам установлены некорректно [Ожидались пути: $expected_pattern1 и $expected_pattern2]/[Получено: $TMP_LOCAL_RUNNER_PATH]"
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
        test_check_archive_unpacking_file_exists_in_root || test_result=1
        test_check_archive_unpacking_file_exists_in_subdir || test_result=1
        test_check_archive_unpacking_file_not_exists || test_result=1
        test_check_archive_unpacking_empty_dir || test_result=1
        test_check_archive_unpacking_with_path_param || test_result=1
        test_check_archive_unpacking_with_invalid_path_param || test_result=1
        test_check_archive_unpacking_similar_filenames || test_result=1
        test_check_archive_unpacking_multiple_subdirs || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _check_archive_unpacking"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_check_archive_unpacking_file_exists_in_root
            test_check_archive_unpacking_file_exists_in_subdir
            test_check_archive_unpacking_file_not_exists
            test_check_archive_unpacking_empty_dir
            test_check_archive_unpacking_with_path_param
            test_check_archive_unpacking_with_invalid_path_param
            test_check_archive_unpacking_similar_filenames
            test_check_archive_unpacking_multiple_subdirs
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _check_archive_unpacking"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_check_archive_unpacking_file_exists_in_root
        test_check_archive_unpacking_file_exists_in_subdir
        test_check_archive_unpacking_file_not_exists
        test_check_archive_unpacking_empty_dir
        test_check_archive_unpacking_with_path_param
        test_check_archive_unpacking_with_invalid_path_param
        test_check_archive_unpacking_similar_filenames
        test_check_archive_unpacking_multiple_subdirs
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi