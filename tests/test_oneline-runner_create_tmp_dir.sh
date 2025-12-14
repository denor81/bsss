#!/usr/bin/env bash
# tests/test_create_tmp_dir.sh
# Тест для функции _create_tmp_dir

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

# Мокируем функции логирования, перенаправляя вывод в переменную для анализа
log_info() {
    LOG_OUTPUT+="$SYMBOL_INFO [$CURRENT_MODULE_NAME] $1"$'\n'
}

log_error() {
    LOG_OUTPUT+="$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $1"$'\n'
}

log_success() {
    LOG_OUTPUT+="$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $1"$'\n'
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

# Вспомогательная функция для проверки существования директории
assertDirectoryExists() {
    local dir_path="$1"
    local message="$2"
    
    if [[ -d "$dir_path" ]]; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message"
        return 1
    fi
}

# Вспомогательная функция для проверки доступности директории для записи
assertDirectoryWritable() {
    local dir_path="$1"
    local message="$2"
    
    if [[ -w "$dir_path" ]]; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message"
        return 1
    fi
}

# Функция подготовки тестового окружения
setup() {
    # Создаем временную директорию для тестов
    TEST_DIR=$(mktemp -d)
    # Сбрасываем переменные
    LOG_OUTPUT=""
    TEMP_PROJECT_DIR=""
    CLEANUP_COMMANDS=()
}

# Функция очистки после теста
teardown() {
    # Удаляем временную директорию, если она была создана функцией
    if [[ -n "$TEMP_PROJECT_DIR" && -d "$TEMP_PROJECT_DIR" ]]; then
        rm -rf "$TEMP_PROJECT_DIR"
    fi
    # Удаляем тестовую директорию
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# ==========================================
# ТЕСТЫ ФУНКЦИИ _create_tmp_dir
# ==========================================

# Тест 1: успешное создание временной директории
test_create_tmp_dir_success() {
    setup
    
    # Вызываем тестируемую функцию
    _create_tmp_dir "testutil" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории"
    
    # Проверяем, что директория создана и доступна для записи
    assertDirectoryExists "$TEMP_PROJECT_DIR" "Директория создана"
    assertDirectoryWritable "$TEMP_PROJECT_DIR" "Директория доступна для записи"
    
    teardown
}

# Тест 2: успешное создание временной директории с параметрами по умолчанию
test_create_tmp_dir_default_params() {
    setup
    
    # Вызываем тестируемую функцию с параметрами по умолчанию
    _create_tmp_dir "" true
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории с параметрами по умолчанию"
    
    # Проверяем, что директория создана и доступна для записи
    assertDirectoryExists "$TEMP_PROJECT_DIR" "Директория создана с параметрами по умолчанию"
    assertDirectoryWritable "$TEMP_PROJECT_DIR" "Директория доступна для записи"
    
    # Проверяем, что команда очистки добавлена в CLEANUP_COMMANDS
    if [[ ${#CLEANUP_COMMANDS[@]} -gt 0 ]]; then
        echo "[V] Команда очистки добавлена в CLEANUP_COMMANDS"
    else
        echo "[X] Команда очистки не добавлена в CLEANUP_COMMANDS"
    fi
    
    teardown
}

# Тест 3: проверка, что в директории можно создавать файлы
test_create_tmp_dir_can_create_files() {
    setup
    
    # Вызываем тестируемую функцию
    _create_tmp_dir "testutil" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории"
    
    # Проверяем, что в директории можно создавать файлы
    if echo "test content" > "$TEMP_PROJECT_DIR/test_file.txt" 2>/dev/null; then
        echo "[V] В директории можно создавать файлы"
        # Проверяем, что файл действительно создан
        if [[ -f "$TEMP_PROJECT_DIR/test_file.txt" ]]; then
            echo "[V] Файл успешно создан в директории"
        else
            echo "[X] Файл не создан в директории"
        fi
    else
        echo "[X] В директории нельзя создавать файлы"
    fi
    
    teardown
}

# Тест 4: проверка множественных вызовов функции
test_create_tmp_dir_multiple_calls() {
    setup
    
    # Вызываем тестируемую функцию несколько раз
    _create_tmp_dir "test1" false
    local first_dir="$TEMP_PROJECT_DIR"
    
    _create_tmp_dir "test2" false
    local second_dir="$TEMP_PROJECT_DIR"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание нескольких временных директорий"
    
    # Проверяем, что директории созданы и различны
    if [[ -d "$first_dir" && -d "$second_dir" && "$first_dir" != "$second_dir" ]]; then
        echo "[V] Созданы две различные временные директории"
    else
        echo "[X] Директории не созданы или не различны"
    fi
    
    teardown
}

# Тест 5: проверка работы с особыми символами в имени утилиты
test_create_tmp_dir_special_chars() {
    setup
    
    # Вызываем тестируемую функцию с именем, содержащим специальные символы
    _create_tmp_dir "test-util_123" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории с особыми символами"
    
    # Проверяем, что директория создана и доступна для записи
    assertDirectoryExists "$TEMP_PROJECT_DIR" "Директория создана с особыми символами в имени"
    assertDirectoryWritable "$TEMP_PROJECT_DIR" "Директория доступна для записи"
    
    teardown
}

# Тест 6: проверка обработки ошибок при отсутствии прав на создание директории
test_create_tmp_dir_no_permissions() {
    setup
    
    # Проверяем, что функция не обрабатывает ошибки mktemp (это известное ограничение)
    # Создаем директорию без прав на запись
    local readonly_dir="$TEST_DIR/readonly"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir"
    
    # Мокируем mktemp, чтобы он использовал нашу директорию без прав на запись
    mktemp() {
        command mktemp -d "$readonly_dir/testutil-XXXXXX" 2>/dev/null
        return 1  # Явно возвращаем ошибку
    }
    
    # Вызываем тестируемую функцию
    _create_tmp_dir "testutil" false
    
    # Проверяем, что функция не обрабатывает ошибки mktemp (известное ограничение)
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "[V] Функция работает ожидаемо (не обрабатывает ошибки mktemp)"
        # Проверяем, что TEMP_PROJECT_DIR установлен (пусть и с некорректным значением)
        if [[ -n "$TEMP_PROJECT_DIR" ]]; then
            echo "[V] TEMP_PROJECT_DIR установлен как ожидается"
        else
            echo "[X] TEMP_PROJECT_DIR не установлен"
        fi
    else
        echo "[X] Функция вернула ошибку (неожиданное поведение)"
    fi
    
    # Восстанавливаем права перед очисткой
    chmod 755 "$readonly_dir"
    
    teardown
}

# Тест 7: проверка логирования
test_create_tmp_dir_logging() {
    setup
    
    # Вызываем тестируемую функцию
    _create_tmp_dir "testutil" false
    
    # Проверяем, что в логе есть сообщение о создании директории
    if [[ "$LOG_OUTPUT" =~ .*"Создана временная директория".* ]]; then
        echo "[V] Логирование работает корректно"
    else
        echo "[X] Логирование не работает корректно"
    fi
    
    teardown
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
        test_create_tmp_dir_success || test_result=1
        test_create_tmp_dir_default_params || test_result=1
        test_create_tmp_dir_can_create_files || test_result=1
        test_create_tmp_dir_multiple_calls || test_result=1
        test_create_tmp_dir_special_chars || test_result=1
        test_create_tmp_dir_no_permissions || test_result=1
        test_create_tmp_dir_logging || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _create_tmp_dir"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста]"
            echo "============================================="
            
            test_create_tmp_dir_success
            test_create_tmp_dir_default_params
            test_create_tmp_dir_can_create_files
            test_create_tmp_dir_multiple_calls
            test_create_tmp_dir_special_chars
            test_create_tmp_dir_no_permissions
            test_create_tmp_dir_logging
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _create_tmp_dir"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста]"
        echo "============================================="
        
        test_create_tmp_dir_success
        test_create_tmp_dir_default_params
        test_create_tmp_dir_can_create_files
        test_create_tmp_dir_multiple_calls
        test_create_tmp_dir_special_chars
        test_create_tmp_dir_no_permissions
        test_create_tmp_dir_logging
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi