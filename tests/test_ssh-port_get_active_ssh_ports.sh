#!/usr/bin/env bash
# tests/test_get_active_ssh_ports.sh
# Тест для функции _get_active_ssh_ports

# Подключаем тестируемый файл
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
CURRENT_MODULE_NAME="test_get_active_ssh_ports"

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
# ТЕСТЫ ФУНКЦИИ _get_active_ssh_ports
# ==========================================

# Тест 1: когда SSH сервис не запущен
test_get_active_ssh_ports_no_ssh() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Мокируем команду ss, чтобы она не нашла SSH порты
    ss() {
        echo "State   Recv-Q  Send-Q Local Address:Port  Peer Address:Port"
        echo "LISTEN  0       128          0.0.0.0:80         0.0.0.0:*"
        echo "LISTEN  0       128             [::]:22            [::]:*"
    }
    
    # Вызываем тестируемую функцию
    local output
    output=$(_get_active_ssh_ports)
    
    # Проверяем, что вывод пустой
    assertEquals "" "$output" "SSH сервис не запущен"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда SSH сервис запущен на порту 22
test_get_active_ssh_ports_default_port() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Мокируем команду ss, чтобы она нашла SSH на порту 22
    ss() {
        echo "State   Recv-Q  Send-Q Local Address:Port  Peer Address:Port"
        echo "LISTEN  0       128          0.0.0.0:80         0.0.0.0:*"
        echo "LISTEN  0       128             [::]:22            [::]:*   users:(\"sshd\",pid=1234,fd=3)"
    }
    
    # Вызываем тестируемую функцию
    local output
    output=$(_get_active_ssh_ports)
    
    # Проверяем, что вывод содержит порт 22
    assertContains "22" "$output" "SSH сервис запущен на порту 22"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: когда SSH сервис запущен на нескольких портах
test_get_active_ssh_ports_multiple_ports() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Мокируем команду ss, чтобы она нашла SSH на портах 22 и 2222
    ss() {
        echo "State   Recv-Q  Send-Q Local Address:Port  Peer Address:Port"
        echo "LISTEN  0       128          0.0.0.0:80         0.0.0.0:*"
        echo "LISTEN  0       128             [::]:22            [::]:*   users:(\"sshd\",pid=1234,fd=3)"
        echo "LISTEN  0       128          0.0.0.0:2222       0.0.0.0:*   users:(\"sshd\",pid=1235,fd=4)"
    }
    
    # Вызываем тестируемую функцию
    local output
    output=$(_get_active_ssh_ports)
    
    # Проверяем, что вывод содержит оба порта
    assertContains "22" "$output" "SSH сервис запущен на порту 22"
    assertContains "2222" "$output" "SSH сервис запущен на порту 2222"
    
    # Дополнительная проверка: убеждаемся, что порты отсортированы и уникальны
    local expected_output="22
2222"
    assertEquals "$expected_output" "$output" "SSH сервис запущен на портах 22 и 2222"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: когда SSH сервис запущен на нестандартном порту
test_get_active_ssh_ports_custom_port() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Мокируем команду ss, чтобы она нашла SSH на порту 3333
    ss() {
        echo "State   Recv-Q  Send-Q Local Address:Port  Peer Address:Port"
        echo "LISTEN  0       128          0.0.0.0:80         0.0.0.0:*"
        echo "LISTEN  0       128          0.0.0.0:3333       0.0.0.0:*   users:(\"sshd\",pid=1234,fd=3)"
    }
    
    # Вызываем тестируемую функцию
    local output
    output=$(_get_active_ssh_ports)
    
    # Проверяем, что вывод содержит порт 3333
    assertContains "3333" "$output" "SSH сервис запущен на порту 3333"
    
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
        test_get_active_ssh_ports_no_ssh || test_result=1
        test_get_active_ssh_ports_default_port || test_result=1
        test_get_active_ssh_ports_multiple_ports || test_result=1
        test_get_active_ssh_ports_custom_port || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _get_active_ssh_ports"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_get_active_ssh_ports_no_ssh
            test_get_active_ssh_ports_default_port
            test_get_active_ssh_ports_multiple_ports
            test_get_active_ssh_ports_custom_port
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _get_active_ssh_ports"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_get_active_ssh_ports_no_ssh
        test_get_active_ssh_ports_default_port
        test_get_active_ssh_ports_multiple_ports
        test_get_active_ssh_ports_custom_port
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi