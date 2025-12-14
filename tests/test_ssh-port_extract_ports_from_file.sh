#!/usr/bin/env bash
# tests/test_extract_ports_from_file.sh
# Тест для функции _extract_ports_from_file

# Подключаем тестируемый файл
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
CURRENT_MODULE_NAME="test_extract_ports_from_file"

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

# Вспомогательная функция для проверки наличия порта в выводе
assertContains() {
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

# ==========================================
# ТЕСТЫ ФУНКЦИИ _extract_ports_from_file
# ==========================================

# Тест 1: когда файл не существует
test_extract_ports_from_file_not_exists() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local non_existent_file="$test_dir/non_existent.conf"
    
    # Вызываем тестируемую функцию с несуществующим файлом
    local output
    output=$(_extract_ports_from_file "$non_existent_file")
    
    # Проверяем, что вывод пустой
    assertEquals "" "$output" "Файл не существует"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда файл существует, но не содержит директив Port или ListenPort
test_extract_ports_from_file_empty() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local config_file="$test_dir/ssh_config.conf"
    
    # Создаем файл без директив Port или ListenPort
    cat > "$config_file" << EOF
# Это комментарий
Protocol 2
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 120
PermitRootLogin no
EOF
    
    # Вызываем тестируемую функцию
    local output
    output=$(_extract_ports_from_file "$config_file")
    
    # Проверяем, что вывод пустой
    assertEquals "" "$output" "Файл без директив Port или ListenPort"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: когда файл содержит одну директиву Port
test_extract_ports_from_file_single_port() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local config_file="$test_dir/ssh_config.conf"
    
    # Создаем файл с одной директивой Port
    cat > "$config_file" << EOF
# Это комментарий
Protocol 2
Port 2222
SyslogFacility AUTH
EOF
    
    # Вызываем тестируемую функцию
    local output
    output=$(_extract_ports_from_file "$config_file")
    
    # Проверяем, что вывод содержит порт 2222
    assertEquals "2222" "$output" "Файл с одной директивой Port"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: когда файл содержит одну директиву ListenPort
test_extract_ports_from_file_single_listenport() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local config_file="$test_dir/ssh_config.conf"
    
    # Создаем файл с одной директивой ListenPort
    cat > "$config_file" << EOF
# Это комментарий
Protocol 2
ListenPort 3333
SyslogFacility AUTH
EOF
    
    # Вызываем тестируемую функцию
    local output
    output=$(_extract_ports_from_file "$config_file")
    
    # Проверяем, что вывод содержит порт 3333
    assertEquals "3333" "$output" "Файл с одной директивой ListenPort"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: когда файл содержит несколько директив Port и ListenPort
test_extract_ports_from_file_multiple_ports() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local config_file="$test_dir/ssh_config.conf"
    
    # Создаем файл с несколькими директивами Port и ListenPort
    cat > "$config_file" << EOF
# Это комментарий
Protocol 2
Port 22
ListenPort 2222
Port 3333
SyslogFacility AUTH
EOF
    
    # Вызываем тестируемую функцию
    local output
    output=$(_extract_ports_from_file "$config_file")
    
    # Проверяем, что вывод содержит все порты
    assertContains "22" "$output" "Файл содержит порт 22"
    assertContains "2222" "$output" "Файл содержит порт 2222"
    assertContains "3333" "$output" "Файл содержит порт 3333"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 6: когда файл содержит закомментированные директивы Port
test_extract_ports_from_file_commented_ports() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local config_file="$test_dir/ssh_config.conf"
    
    # Создаем файл с закомментированными директивами Port
    cat > "$config_file" << EOF
# Это комментарий
Protocol 2
# Port 22
#ListenPort 2222
Port 3333
SyslogFacility AUTH
EOF
    
    # Вызываем тестируемую функцию
    local output
    output=$(_extract_ports_from_file "$config_file")
    
    # Проверяем, что вывод содержит только незакомментированный порт
    assertContains "3333" "$output" "Файл содержит порт 3333"
    
    # Проверяем, что вывод не содержит закомментированные порты
    if [[ "$output" == *"22"* ]]; then
        echo "[X] Файл не должен содержать закомментированный порт 22"
        return 1
    else
        echo "[V] Файл не содержит закомментированный порт 22"
    fi
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 7: когда файл содержит директивы Port с некорректными значениями
test_extract_ports_from_file_invalid_ports() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    local config_file="$test_dir/ssh_config.conf"
    
    # Создаем файл с некорректными значениями портов
    cat > "$config_file" << EOF
# Это комментарий
Protocol 2
Port 22
Port abc
Port 123abc
Port 3333
SyslogFacility AUTH
EOF
    
    # Вызываем тестируемую функцию
    local output
    output=$(_extract_ports_from_file "$config_file")
    
    # Проверяем, что вывод содержит только корректные порты
    assertContains "22" "$output" "Файл содержит порт 22"
    assertContains "3333" "$output" "Файл содержит порт 3333"
    
    # Проверяем, что вывод не содержит некорректные порты
    if [[ "$output" == *"abc"* ]]; then
        echo "[X] Файл не должен содержать некорректный порт abc"
        return 1
    else
        echo "[V] Файл не содержит некорректный порт abc"
    fi
    
    if [[ "$output" == *"123abc"* ]]; then
        echo "[X] Файл не должен содержать некорректный порт 123abc"
        return 1
    else
        echo "[V] Файл не содержит некорректный порт 123abc"
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
        test_output=""
        test_result=0
        
        # Запускаем тесты и захватываем вывод
        test_extract_ports_from_file_not_exists || test_result=1
        test_extract_ports_from_file_empty || test_result=1
        test_extract_ports_from_file_single_port || test_result=1
        test_extract_ports_from_file_single_listenport || test_result=1
        test_extract_ports_from_file_multiple_ports || test_result=1
        test_extract_ports_from_file_commented_ports || test_result=1
        test_extract_ports_from_file_invalid_ports || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _extract_ports_from_file"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_extract_ports_from_file_not_exists
            test_extract_ports_from_file_empty
            test_extract_ports_from_file_single_port
            test_extract_ports_from_file_single_listenport
            test_extract_ports_from_file_multiple_ports
            test_extract_ports_from_file_commented_ports
            test_extract_ports_from_file_invalid_ports
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _extract_ports_from_file"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_extract_ports_from_file_not_exists
        test_extract_ports_from_file_empty
        test_extract_ports_from_file_single_port
        test_extract_ports_from_file_single_listenport
        test_extract_ports_from_file_multiple_ports
        test_extract_ports_from_file_commented_ports
        test_extract_ports_from_file_invalid_ports
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi