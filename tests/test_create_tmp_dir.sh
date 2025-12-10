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

# Мокируем все функции логирования, чтобы избежать вывода
log_info() {
    : # Ничего не делаем, подавляем вывод
}

log_error() {
    : # Ничего не делаем, подавляем вывод
}

log_success() {
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
# ТЕСТЫ ФУНКЦИИ _create_tmp_dir
# ==========================================

# Тест 1: успешное создание временной директории с параметрами
test_create_tmp_dir_success() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию с параметром util_name и без добавления в CLEANUP_COMMANDS
    _create_tmp_dir "testutil" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории"
    
    # Проверяем, что директория действительно создана и имеет правильный префикс
    if [[ -n "$TEMP_PROJECT_DIR" && -d "$TEMP_PROJECT_DIR" ]]; then
        local dirname=$(basename "$TEMP_PROJECT_DIR")
        if [[ "$dirname" =~ ^testutil ]]; then
            echo "[V] Директория создана с правильным префиксом"
        else
            echo "[X] Директория создана с неправильным префиксом"
        fi
        # Удаляем временную директорию вручную, так как мы не добавили ее в CLEANUP_COMMANDS
        rm -rf "$TEMP_PROJECT_DIR"
    else
        echo "[X] Директория не создана или не найдена"
    fi
    
    # Очищаем тестовую директорию
    rm -rf "$test_dir"
}

# Тест 2: создание временной директории с параметром по умолчанию
test_create_tmp_dir_default_param() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию без параметров (использует UTIL_NAME по умолчанию)
    _create_tmp_dir "" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории с параметром по умолчанию"
    
    # Проверяем, что директория действительно создана и имеет префикс UTIL_NAME
    if [[ -n "$TEMP_PROJECT_DIR" && -d "$TEMP_PROJECT_DIR" ]]; then
        local dirname=$(basename "$TEMP_PROJECT_DIR")
        if [[ "$dirname" =~ ^bsss ]]; then
            echo "[V] Директория создана с префиксом по умолчанию"
        else
            echo "[X] Директория создана с неправильным префиксом по умолчанию"
        fi
        # Удаляем временную директорию вручную
        rm -rf "$TEMP_PROJECT_DIR"
    else
        echo "[X] Директория не создана или не найдена"
    fi
    
    # Очищаем тестовую директорию
    rm -rf "$test_dir"
}

# Тест 3: проверка добавления в CLEANUP_COMMANDS
test_create_tmp_dir_add_to_cleanup() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Инициализируем CLEANUP_COMMANDS для чистоты теста
    CLEANUP_COMMANDS=()
    
    # Вызываем тестируемую функцию с добавлением в CLEANUP_COMMANDS
    _create_tmp_dir "testutil" true
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории с добавлением в CLEANUP_COMMANDS"
    
    # Проверяем, что CLEANUP_COMMANDS увеличился на 1
    local new_size=${#CLEANUP_COMMANDS[@]}
    if [[ $new_size -eq 1 ]]; then
        echo "[V] Команда очистки добавлена в CLEANUP_COMMANDS"
    else
        echo "[X] Команда очистки не добавлена в CLEANUP_COMMANDS"
    fi
    
    # Проверяем, что директория действительно создана
    if [[ -n "$TEMP_PROJECT_DIR" && -d "$TEMP_PROJECT_DIR" ]]; then
        echo "[V] Директория создана"
        # Удаляем вручную, так как это тест
        rm -rf "$TEMP_PROJECT_DIR"
    else
        echo "[X] Директория не создана или не найдена"
    fi
    
    # Очищаем тестовую директорию
    rm -rf "$test_dir"
}

# Тест 4: проверка глобальной переменной TEMP_PROJECT_DIR
test_create_tmp_dir_global_var() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Сбрасываем TEMP_PROJECT_DIR
    TEMP_PROJECT_DIR=""
    
    # Вызываем тестируемую функцию
    _create_tmp_dir "testutil" false
    
    # Проверяем, что TEMP_PROJECT_DIR установлен
    if [[ -n "$TEMP_PROJECT_DIR" ]]; then
        echo "[V] Глобальная переменная TEMP_PROJECT_DIR установлена"
        
        # Проверяем, что это действительно директория
        if [[ -d "$TEMP_PROJECT_DIR" ]]; then
            echo "[V] TEMP_PROJECT_DIR является директорией"
        else
            echo "[X] TEMP_PROJECT_DIR не является директорией"
        fi
        
        # Удаляем временную директорию вручную
        rm -rf "$TEMP_PROJECT_DIR"
    else
        echo "[X] Глобальная переменная TEMP_PROJECT_DIR не установлена"
    fi
    
    # Очищаем тестовую директорию
    rm -rf "$test_dir"
}

# Тест 5: проверка с особыми символами в имени утилиты
test_create_tmp_dir_special_chars() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию с именем, содержащим специальные символы
    _create_tmp_dir "test-util_123" false
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории с особыми символами"
    
    # Проверяем, что директория действительно создана и имеет правильный префикс
    if [[ -n "$TEMP_PROJECT_DIR" && -d "$TEMP_PROJECT_DIR" ]]; then
        local dirname=$(basename "$TEMP_PROJECT_DIR")
        if [[ "$dirname" =~ ^test-util_123 ]]; then
            echo "[V] Директория создана с правильным префиксом с особыми символами"
        else
            echo "[X] Директория создана с неправильным префиксом с особыми символами"
        fi
        # Удаляем временную директорию вручную
        rm -rf "$TEMP_PROJECT_DIR"
    else
        echo "[X] Директория не создана или не найдена"
    fi
    
    # Очищаем тестовую директорию
    rm -rf "$test_dir"
}

# Тест 6: проверка множественных вызовов функции
test_create_tmp_dir_multiple_calls() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Инициализируем CLEANUP_COMMANDS для чистоты теста
    CLEANUP_COMMANDS=()
    
    # Вызываем тестируемую функцию несколько раз
    _create_tmp_dir "test1" true
    local first_dir="$TEMP_PROJECT_DIR"
    
    _create_tmp_dir "test2" true
    local second_dir="$TEMP_PROJECT_DIR"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание нескольких временных директорий"
    
    # Проверяем, что CLEANUP_COMMANDS содержит 2 команды
    local cleanup_size=${#CLEANUP_COMMANDS[@]}
    if [[ $cleanup_size -eq 2 ]]; then
        echo "[V] Обе команды очистки добавлены в CLEANUP_COMMANDS"
    else
        echo "[X] Не все команды очистки добавлены в CLEANUP_COMMANDS"
    fi
    
    # Проверяем, что директории действительно созданы и различны
    if [[ -n "$first_dir" && -d "$first_dir" && -n "$second_dir" && -d "$second_dir" && "$first_dir" != "$second_dir" ]]; then
        echo "[V] Созданы две различные временные директории"
        # Удаляем вручную, так как это тест
        rm -rf "$first_dir"
        rm -rf "$second_dir"
    else
        echo "[X] Директории не созданы или не различны"
    fi
    
    # Очищаем тестовую директорию
    rm -rf "$test_dir"
}

# Тест 7: проверка работы с пустым CLEANUP_COMMANDS
test_create_tmp_dir_empty_cleanup() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Сбрасываем CLEANUP_COMMANDS
    CLEANUP_COMMANDS=()
    
    # Вызываем тестируемую функцию с добавлением в CLEANUP_COMMANDS
    _create_tmp_dir "testutil" true
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное создание временной директории с пустым CLEANUP_COMMANDS"
    
    # Проверяем, что CLEANUP_COMMANDS содержит 1 команду
    local cleanup_size=${#CLEANUP_COMMANDS[@]}
    if [[ $cleanup_size -eq 1 ]]; then
        echo "[V] Команда очистки добавлена в пустой CLEANUP_COMMANDS"
    else
        echo "[X] Команда очистки не добавлена в пустой CLEANUP_COMMANDS"
    fi
    
    # Проверяем, что директория действительно создана
    if [[ -n "$TEMP_PROJECT_DIR" && -d "$TEMP_PROJECT_DIR" ]]; then
        echo "[V] Директория создана"
        # Удаляем вручную, так как это тест
        rm -rf "$TEMP_PROJECT_DIR"
    else
        echo "[X] Директория не создана или не найдена"
    fi
    
    # Очищаем тестовую директорию
    rm -rf "$test_dir"
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _create_tmp_dir"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
    echo "============================================="
    
    test_create_tmp_dir_success
    test_create_tmp_dir_default_param
    test_create_tmp_dir_add_to_cleanup
    test_create_tmp_dir_global_var
    test_create_tmp_dir_special_chars
    test_create_tmp_dir_multiple_calls
    test_create_tmp_dir_empty_cleanup
    
    echo "============================================="
    echo "Тесты завершены"
fi