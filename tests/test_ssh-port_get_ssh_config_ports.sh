#!/usr/bin/env bash
# tests/test_get_ssh_config_ports.sh
# Тест для функции get_ssh_config_ports

# Включаем строгий режим выполнения
set -Eeuo pipefail

# Подключаем тестируемый файл
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
CURRENT_MODULE_NAME="test_get_ssh_config_ports"
# Хранилище для временных директорий, созданных в тестах
TEST_TEMP_DIRS=()

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

# Функция для очистки временных директорий
cleanup_temp_dirs() {
    for dir in "${TEST_TEMP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
        fi
    done
    TEST_TEMP_DIRS=()
}

# Устанавливаем trap для гарантированной очистки ресурсов
trap cleanup_temp_dirs EXIT

# Мокируем функции логирования, чтобы избежать вывода в нашем формате
log_error() {
    : # Ничего не делаем, подавляем вывод
}

log_info() {
    : # Ничего не делаем, подавляем вывод
}

log_success() {
    : # Ничего не делаем, подавляем вывод
}

# Вспомогательная функция для сравнения результатов
assertEquals() {
    # Проверяем наличие обязательных параметров
    if [[ $# -ne 3 ]]; then
        echo "[X] assertEquals требует 3 параметра: expected, actual, message"
        return 1
    fi
    
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

# Вспомогательная функция для проверки наличия порта в выводе
assertContains() {
    # Проверяем наличие обязательных параметров
    if [[ $# -ne 3 ]]; then
        echo "[X] assertContains требует 3 параметра: expected, actual, message"
        return 1
    fi
    
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [[ "$actual" != *"$expected"* ]]; then
        echo "[X] $message [$expected]/[$actual]"
        return 1
    else
        echo "[V] $message [$expected]/[$actual]"
        return 0
    fi
}

# Вспомогательная функция для выполнения тестируемой функции с обработкой ошибок
run_test_function() {
    local test_func="$1"
    shift
    
    # Временно отключаем set -e для корректного отлова кода возврата
    set +e
    local output
    local exit_code
    output=$("$test_func" "$@" 2>&1)
    exit_code=$?
    set -e
    
    # Возвращаем результат через глобальные переменные
    TEST_OUTPUT="$output"
    TEST_EXIT_CODE="$exit_code"
}

# ==========================================
# ТЕСТЫ ФУНКЦИИ get_ssh_config_ports
# ==========================================

# Тест 1: когда основной конфигурационный файл не существует
test_get_ssh_config_ports_main_file_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    # Добавляем директорию в список для очистки
    TEST_TEMP_DIRS+=("$test_dir")
    
    local non_existent_file="$test_dir/non_existent_ssh_config"
    local config_dir="$test_dir/empty_ssh_config_dir"
    
    # Создаем пустую директорию для конфигурации
    mkdir -p "$config_dir"
    
    # Вызываем тестируемую функцию с несуществующим файлом
    run_test_function get_ssh_config_ports "$non_existent_file" "$config_dir"
    
    # Проверяем, что функция вернула код ошибки
    assertEquals 1 $TEST_EXIT_CODE "Функция должна вернуть код ошибки 1"
}

# Тест 2: когда директория конфигурации не существует
test_get_ssh_config_ports_config_dir_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    # Добавляем директорию в список для очистки
    TEST_TEMP_DIRS+=("$test_dir")
    
    local main_config="$test_dir/ssh_config"
    local non_existent_dir="$test_dir/non_existent_ssh_config_dir"
    
    # Создаем основной конфигурационный файл без портов
    cat > "$main_config" << EOF
# Это комментарий
Protocol 2
SyslogFacility AUTH
EOF
    
    # Вызываем тестируемую функцию с несуществующей директорией
    run_test_function get_ssh_config_ports "$main_config" "$non_existent_dir"
    
    # Проверяем, что функция вернула код ошибки
    assertEquals 1 $TEST_EXIT_CODE "Функция должна вернуть код ошибки 1"
}

# Тест 3: когда основной конфигурационный файл содержит один порт
test_get_ssh_config_ports_main_file_single_port() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    # Добавляем директорию в список для очистки
    TEST_TEMP_DIRS+=("$test_dir")
    
    local main_config="$test_dir/ssh_config"
    local config_dir="$test_dir/empty_ssh_config_dir"
    
    # Создаем пустую директорию для конфигурации
    mkdir -p "$config_dir"
    
    # Создаем основной конфигурационный файл с одним портом
    cat > "$main_config" << EOF
# Это комментарий
Protocol 2
Port 2222
SyslogFacility AUTH
EOF
    
    # Вызываем тестируемую функцию
    run_test_function get_ssh_config_ports "$main_config" "$config_dir"
    
    # Проверяем, что функция вернула код успеха
    assertEquals 0 $TEST_EXIT_CODE "Функция должна вернуть код успеха 0"
    
    # Проверяем, что вывод содержит порт 2222
    assertContains "2222" "$TEST_OUTPUT" "Вывод должен содержать порт 2222"
}

# Тест 4: когда в директории конфигурации есть файлы с портами
test_get_ssh_config_ports_config_dir_with_ports() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    # Добавляем директорию в список для очистки
    TEST_TEMP_DIRS+=("$test_dir")
    
    local main_config="$test_dir/ssh_config"
    local config_dir="$test_dir/ssh_config_dir"
    local config_file1="$config_dir/01-ssh.conf"
    local config_file2="$config_dir/02-ssh.conf"
    
    # Создаем директорию для конфигурации
    mkdir -p "$config_dir"
    
    # Создаем основной конфигурационный файл без портов
    cat > "$main_config" << EOF
# Это комментарий
Protocol 2
SyslogFacility AUTH
EOF
    
    # Создаем первый конфигурационный файл с портом
    cat > "$config_file1" << EOF
# Первый конфигурационный файл
Port 3333
EOF
    
    # Создаем второй конфигурационный файл с портом
    cat > "$config_file2" << EOF
# Второй конфигурационный файл
ListenPort 4444
EOF
    
    # Вызываем тестируемую функцию
    run_test_function get_ssh_config_ports "$main_config" "$config_dir"
    
    # Проверяем, что функция вернула код успеха
    assertEquals 0 $TEST_EXIT_CODE "Функция должна вернуть код успеха 0"
    
    # Проверяем, что вывод содержит оба порта
    assertContains "3333" "$TEST_OUTPUT" "Вывод должен содержать порт 3333"
    assertContains "4444" "$TEST_OUTPUT" "Вывод должен содержать порт 4444"
}

# Тест 5: когда и основной файл, и файлы в директории содержат порты
test_get_ssh_config_ports_both_sources_with_ports() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    # Добавляем директорию в список для очистки
    TEST_TEMP_DIRS+=("$test_dir")
    
    local main_config="$test_dir/ssh_config"
    local config_dir="$test_dir/ssh_config_dir"
    local config_file1="$config_dir/01-ssh.conf"
    local config_file2="$config_dir/02-ssh.conf"
    
    # Создаем директорию для конфигурации
    mkdir -p "$config_dir"
    
    # Создаем основной конфигурационный файл с портом
    cat > "$main_config" << EOF
# Основной конфигурационный файл
Protocol 2
Port 22
EOF
    
    # Создаем первый конфигурационный файл с портом
    cat > "$config_file1" << EOF
# Первый конфигурационный файл
Port 2222
EOF
    
    # Создаем второй конфигурационный файл с портом
    cat > "$config_file2" << EOF
# Второй конфигурационный файл
ListenPort 3333
EOF
    
    # Вызываем тестируемую функцию
    run_test_function get_ssh_config_ports "$main_config" "$config_dir"
    
    # Проверяем, что функция вернула код успеха
    assertEquals 0 $TEST_EXIT_CODE "Функция должна вернуть код успеха 0"
    
    # Проверяем, что вывод содержит все порты
    assertContains "22" "$TEST_OUTPUT" "Вывод должен содержать порт 22"
    assertContains "2222" "$TEST_OUTPUT" "Вывод должен содержать порт 2222"
    assertContains "3333" "$TEST_OUTPUT" "Вывод должен содержать порт 3333"
}

# Тест 6: проверка уникальности и сортировки портов
test_get_ssh_config_ports_unique_sorted_ports() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    # Добавляем директорию в список для очистки
    TEST_TEMP_DIRS+=("$test_dir")
    
    local main_config="$test_dir/ssh_config"
    local config_dir="$test_dir/ssh_config_dir"
    local config_file1="$config_dir/01-ssh.conf"
    local config_file2="$config_dir/02-ssh.conf"
    
    # Создаем директорию для конфигурации
    mkdir -p "$config_dir"
    
    # Создаем основной конфигурационный файл с портом
    cat > "$main_config" << EOF
# Основной конфигурационный файл
Protocol 2
Port 3333
EOF
    
    # Создаем первый конфигурационный файл с портом
    cat > "$config_file1" << EOF
# Первый конфигурационный файл
Port 2222
EOF
    
    # Создаем второй конфигурационный файл с дублирующим портом
    cat > "$config_file2" << EOF
# Второй конфигурационный файл
Port 3333
ListenPort 1111
EOF
    
    # Вызываем тестируемую функцию
    run_test_function get_ssh_config_ports "$main_config" "$config_dir"
    
    # Проверяем, что функция вернула код успеха
    assertEquals 0 $TEST_EXIT_CODE "Функция должна вернуть код успеха 0"
    
    # Проверяем, что вывод содержит все уникальные порты
    assertContains "1111" "$TEST_OUTPUT" "Вывод должен содержать порт 1111"
    assertContains "2222" "$TEST_OUTPUT" "Вывод должен содержать порт 2222"
    assertContains "3333" "$TEST_OUTPUT" "Вывод должен содержать порт 3333"
    
    # Проверяем, что порты отсортированы по возрастанию
    # Преобразуем вывод в массив портов для проверки
    local ports_array
    readarray -t ports_array <<< "$TEST_OUTPUT"
    
    # Проверяем, что порты отсортированы
    local is_sorted=true
    for ((i=1; i<${#ports_array[@]}; i++)); do
        if [[ ${ports_array[i-1]} -gt ${ports_array[i]} ]]; then
            is_sorted=false
            break
        fi
    done
    
    if [[ "$is_sorted" == "true" ]]; then
        echo "[V] Порты отсортированы по возрастанию"
    else
        echo "[X] Порты не отсортированы по возрастанию"
        return 1
    fi
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
        test_get_ssh_config_ports_main_file_not_exists || test_result=1
        test_get_ssh_config_ports_config_dir_not_exists || test_result=1
        test_get_ssh_config_ports_main_file_single_port || test_result=1
        test_get_ssh_config_ports_config_dir_with_ports || test_result=1
        test_get_ssh_config_ports_both_sources_with_ports || test_result=1
        test_get_ssh_config_ports_unique_sorted_ports || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции get_ssh_config_ports"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_get_ssh_config_ports_main_file_not_exists
            test_get_ssh_config_ports_config_dir_not_exists
            test_get_ssh_config_ports_main_file_single_port
            test_get_ssh_config_ports_config_dir_with_ports
            test_get_ssh_config_ports_both_sources_with_ports
            test_get_ssh_config_ports_unique_sorted_ports
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции get_ssh_config_ports"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_get_ssh_config_ports_main_file_not_exists
        test_get_ssh_config_ports_config_dir_not_exists
        test_get_ssh_config_ports_main_file_single_port
        test_get_ssh_config_ports_config_dir_with_ports
        test_get_ssh_config_ports_both_sources_with_ports
        test_get_ssh_config_ports_unique_sorted_ports
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi