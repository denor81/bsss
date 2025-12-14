#!/usr/bin/env bash
# tests/test_ssh-port_check.sh
# Тест для функции check из modules/04-ssh-port.sh

# Подключаем тестируемый файл
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

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

# Вспомогательная функция для проверки наличия строки в выводе
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
# ТЕСТЫ ФУНКЦИИ check
# ==========================================

# Тест 1: когда активные порты отсутствуют
test_check_no_active_ports() {
    # Мокируем _collect_ssh_ports_data, чтобы она установила пустые активные порты
    _collect_ssh_ports_data() {
        COLLECTED_ACTIVE_PORTS=""
        COLLECTED_CONFIG_PORTS="22"
    }
    
    # Временно отключаем строгий режим выполнения
    set +e
    # Вызываем тестируемую функцию в режиме парсинга (out_msg_type=0)
    local output
    output=$(check 0)
    local exit_code=$?
    # Возвращаем строгий режим выполнения
    set -e
    
    # Проверяем, что функция вернула код ошибки
    assertEquals 1 $exit_code "Функция должна вернуть код ошибки 1 при отсутствии активных портов"
    
    # Проверяем, что вывод содержит переменную status=1
    assertContains "status=1" "$output" "Вывод должен содержать status=1"
    
    # Проверяем, что вывод содержит переменную active_ssh_port (пустую)
    assertContains "active_ssh_port=" "$output" "Вывод должен содержать пустую переменную active_ssh_port"
}

# Тест 2: когда активные порты есть и совпадают с конфигурационными
test_check_matching_ports() {
    # Мокируем _collect_ssh_ports_data, чтобы она установила совпадающие порты
    _collect_ssh_ports_data() {
        COLLECTED_ACTIVE_PORTS="22,2222"
        COLLECTED_CONFIG_PORTS="22,2222"
    }
    
    # Временно отключаем строгий режим выполнения
    set +e
    # Вызываем тестируемую функцию в режиме парсинга (out_msg_type=0)
    local output
    output=$(check 0)
    local exit_code=$?
    # Возвращаем строгий режим выполнения
    set -e
    
    # Проверяем, что функция вернула код успеха
    assertEquals 0 $exit_code "Функция должна вернуть код успеха 0 при совпадении портов"
    
    # Проверяем, что вывод содержит переменную status=0
    assertContains "status=0" "$output" "Вывод должен содержать status=0"
    
    # Проверяем, что вывод содержит переменные с портами
    assertContains "active_ssh_port=22,2222" "$output" "Вывод должен содержать active_ssh_port=22,2222"
    assertContains "config_files_ssh_port=22,2222" "$output" "Вывод должен содержать config_files_ssh_port=22,2222"
}

# Тест 3: когда активные порты есть, но не совпадают с конфигурационными
test_check_mismatching_ports() {
    # Мокируем _collect_ssh_ports_data, чтобы она установила несовпадающие порты
    _collect_ssh_ports_data() {
        COLLECTED_ACTIVE_PORTS="22,3333"
        COLLECTED_CONFIG_PORTS="22,2222"
    }
    
    # Временно отключаем строгий режим выполнения
    set +e
    # Вызываем тестируемую функцию в режиме парсинга (out_msg_type=0)
    local output
    output=$(check 0)
    local exit_code=$?
    # Возвращаем строгий режим выполнения
    set -e
    
    # Проверяем, что функция вернула код успеха
    assertEquals 0 $exit_code "Функция должна вернуть код успеха 0 при несовпадении портов"
    
    # Проверяем, что вывод содержит переменную status=0
    assertContains "status=0" "$output" "Вывод должен содержать status=0"
    
    # Проверяем, что вывод содержит переменные с портами
    assertContains "active_ssh_port=22,3333" "$output" "Вывод должен содержать active_ssh_port=22,3333"
    assertContains "config_files_ssh_port=22,2222" "$output" "Вывод должен содержать config_files_ssh_port=22,2222"
}

# Тест 4: когда функция вызывается в режиме вывода пользователю (out_msg_type=1)
test_check_user_output_mode() {
    # Мокируем _collect_ssh_ports_data, чтобы она установила совпадающие порты
    _collect_ssh_ports_data() {
        COLLECTED_ACTIVE_PORTS="22"
        COLLECTED_CONFIG_PORTS="22"
    }
    
    # Временно отключаем строгий режим выполнения
    set +e
    # Вызываем тестируемую функцию в режиме вывода пользователю (out_msg_type=1)
    local output
    output=$(check 1)
    local exit_code=$?
    # Возвращаем строгий режим выполнения
    set -e
    
    # Проверяем, что функция вернула код успеха
    assertEquals 0 $exit_code "Функция должна вернуть код успеха 0 в режиме вывода пользователю"
    
    # Проверяем, что вывод содержит только сообщение (без переменных для парсинга)
    assertContains "[V] SSH работает на портах: 22" "$output" "Вывод должен содержать сообщение"
    
    # Проверяем, что вывод не содержит переменных для парсинга
    if [[ "$output" == *"message="* ]]; then
        echo "[X] Вывод не должен содержать переменные для парсинга"
        return 1
    else
        echo "[V] Вывод не содержит переменные для парсинга"
    fi
}

# Тест 5: когда используется нестандартный порт по умолчанию
test_check_custom_default_port() {
    # Мокируем _collect_ssh_ports_data, чтобы она установила пустые активные порты
    _collect_ssh_ports_data() {
        COLLECTED_ACTIVE_PORTS=""
        COLLECTED_CONFIG_PORTS="3333"
    }
    
    # Временно отключаем строгий режим выполнения
    set +e
    # Вызываем тестируемую функцию с нестандартным портом по умолчанию
    local output
    output=$(check 0 3333)
    local exit_code=$?
    # Возвращаем строгий режим выполнения
    set -e
    
    # Проверяем, что функция вернула код ошибки
    assertEquals 1 $exit_code "Функция должна вернуть код ошибки 1 при отсутствии активных портов"
    
    # Проверяем, что вывод содержит переменную status=1
    assertContains "status=1" "$output" "Вывод должен содержать status=1"
    
    # Проверяем, что вывод содержит переменную config_files_ssh_port=3333
    assertContains "config_files_ssh_port=3333" "$output" "Вывод должен содержать config_files_ssh_port=3333"
}

# Тест 6: когда активные порты содержат только один порт
test_check_single_active_port() {
    # Мокируем _collect_ssh_ports_data, чтобы она установила один активный порт
    _collect_ssh_ports_data() {
        COLLECTED_ACTIVE_PORTS="2222"
        COLLECTED_CONFIG_PORTS="22,2222"
    }
    
    # Временно отключаем строгий режим выполнения
    set +e
    # Вызываем тестируемую функцию в режиме парсинга (out_msg_type=0)
    local output
    output=$(check 0)
    local exit_code=$?
    # Возвращаем строгий режим выполнения
    set -e
    
    # Проверяем, что функция вернула код успеха
    assertEquals 0 $exit_code "Функция должна вернуть код успеха 0"
    
    # Проверяем, что вывод содержит переменную status=0
    assertContains "status=0" "$output" "Вывод должен содержать status=0"
    
    # Проверяем, что вывод содержит переменные с портами
    assertContains "active_ssh_port=2222" "$output" "Вывод должен содержать active_ssh_port=2222"
    assertContains "config_files_ssh_port=22,2222" "$output" "Вывод должен содержать config_files_ssh_port=22,2222"
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
        test_check_no_active_ports || test_result=1
        test_check_matching_ports || test_result=1
        test_check_mismatching_ports || test_result=1
        test_check_user_output_mode || test_result=1
        test_check_custom_default_port || test_result=1
        test_check_single_active_port || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции check"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_check_no_active_ports
            test_check_matching_ports
            test_check_mismatching_ports
            test_check_user_output_mode
            test_check_custom_default_port
            test_check_single_active_port
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции check"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_check_no_active_ports
        test_check_matching_ports
        test_check_mismatching_ports
        test_check_user_output_mode
        test_check_custom_default_port
        test_check_single_active_port
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi