#!/usr/bin/env bash
# tests/test_collect_ssh_ports_data.sh
# Тест для функции _collect_ssh_ports_data

# Подключаем тестируемый файл
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================
# Переменные, необходимые для работы тестового файла
CURRENT_MODULE_NAME="test_collect_ssh_ports_data"

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

# ==========================================
# ТЕСТЫ ФУНКЦИИ _collect_ssh_ports_data
# ==========================================

# Тест 1: когда активные порты отсутствуют, а конфигурационные порты есть
test_collect_ssh_ports_data_no_active_ports() {
    # Мокируем функцию _get_active_ssh_ports, чтобы она возвращала пустой результат
    _get_active_ssh_ports() {
        echo ""
    }
    
    # Мокируем функцию get_ssh_config_ports, чтобы она возвращала порты 22 и 2222
    get_ssh_config_ports() {
        echo "22"
        echo "2222"
    }
    
    # Вызываем тестируемую функцию и проверяем код возврата
    local exit_code
    _collect_ssh_ports_data
    exit_code=$?
    
    # Проверяем, что функция завершилась успешно
    assertEquals 0 $exit_code "Функция должна завершиться с кодом 0"
    
    # Проверяем, что глобальные переменные установлены правильно
    assertEquals "" "$COLLECTED_ACTIVE_PORTS" "Активные порты должны быть пустыми"
    assertEquals "22,2222" "$COLLECTED_CONFIG_PORTS" "Конфигурационные порты должны быть '22,2222'"
}

# Тест 2: когда активные порты есть, а конфигурационные порты отсутствуют
test_collect_ssh_ports_data_no_config_ports() {
    # Мокируем функцию _get_active_ssh_ports, чтобы она возвращала порты 22 и 3333
    _get_active_ssh_ports() {
        echo "22"
        echo "3333"
    }
    
    # Мокируем функцию get_ssh_config_ports, чтобы она возвращала код ошибки
    get_ssh_config_ports() {
        return 1
    }
    
    # Вызываем тестируемую функцию и проверяем код возврата
    local exit_code
    _collect_ssh_ports_data
    exit_code=$?
    
    # Проверяем, что функция завершилась успешно
    assertEquals 0 $exit_code "Функция должна завершиться с кодом 0"
    
    # Проверяем, что глобальные переменные установлены правильно
    assertEquals "22,3333" "$COLLECTED_ACTIVE_PORTS" "Активные порты должны быть '22,3333'"
    assertEquals "22" "$COLLECTED_CONFIG_PORTS" "Конфигурационные порты должны быть '22' (по умолчанию)"
}

# Тест 3: когда и активные, и конфигурационные порты есть и совпадают
test_collect_ssh_ports_data_matching_ports() {
    # Мокируем функцию _get_active_ssh_ports, чтобы она возвращала порты 22 и 2222
    _get_active_ssh_ports() {
        echo "22"
        echo "2222"
    }
    
    # Мокируем функцию get_ssh_config_ports, чтобы она возвращала те же порты
    get_ssh_config_ports() {
        echo "22"
        echo "2222"
    }
    
    # Вызываем тестируемую функцию и проверяем код возврата
    local exit_code
    _collect_ssh_ports_data
    exit_code=$?
    
    # Проверяем, что функция завершилась успешно
    assertEquals 0 $exit_code "Функция должна завершиться с кодом 0"
    
    # Проверяем, что глобальные переменные установлены правильно
    assertEquals "22,2222" "$COLLECTED_ACTIVE_PORTS" "Активные порты должны быть '22,2222'"
    assertEquals "22,2222" "$COLLECTED_CONFIG_PORTS" "Конфигурационные порты должны быть '22,2222'"
}

# Тест 4: когда активные и конфигурационные порты есть, но не совпадают
test_collect_ssh_ports_data_mismatching_ports() {
    # Мокируем функцию _get_active_ssh_ports, чтобы она возвращала порты 22 и 3333
    _get_active_ssh_ports() {
        echo "22"
        echo "3333"
    }
    
    # Мокируем функцию get_ssh_config_ports, чтобы она возвращала другие порты
    get_ssh_config_ports() {
        echo "22"
        echo "2222"
    }
    
    # Вызываем тестируемую функцию и проверяем код возврата
    local exit_code
    _collect_ssh_ports_data
    exit_code=$?
    
    # Проверяем, что функция завершилась успешно
    assertEquals 0 $exit_code "Функция должна завершиться с кодом 0"
    
    # Проверяем, что глобальные переменные установлены правильно
    assertEquals "22,3333" "$COLLECTED_ACTIVE_PORTS" "Активные порты должны быть '22,3333'"
    assertEquals "22,2222" "$COLLECTED_CONFIG_PORTS" "Конфигурационные порты должны быть '22,2222'"
}

# Тест 5: когда указан нестандартный порт по умолчанию
test_collect_ssh_ports_data_custom_default_port() {
    # Мокируем функцию _get_active_ssh_ports, чтобы она возвращала пустой результат
    _get_active_ssh_ports() {
        echo ""
    }
    
    # Мокируем функцию get_ssh_config_ports, чтобы она возвращала код ошибки
    get_ssh_config_ports() {
        return 1
    }
    
    # Вызываем тестируемую функцию с нестандартным портом по умолчанию и проверяем код возврата
    local exit_code
    _collect_ssh_ports_data 3333
    exit_code=$?
    
    # Проверяем, что функция завершилась успешно
    assertEquals 0 $exit_code "Функция должна завершиться с кодом 0"
    
    # Проверяем, что глобальные переменные установлены правильно
    assertEquals "" "$COLLECTED_ACTIVE_PORTS" "Активные порты должны быть пустыми"
    assertEquals "3333" "$COLLECTED_CONFIG_PORTS" "Конфигурационные порты должны быть '3333' (пользовательский порт по умолчанию)"
}

# Тест 6: когда активные порты содержат только один порт
test_collect_ssh_ports_data_single_active_port() {
    # Мокируем функцию _get_active_ssh_ports, чтобы она возвращала один порт
    _get_active_ssh_ports() {
        echo "2222"
    }
    
    # Мокируем функцию get_ssh_config_ports, чтобы она возвращала несколько портов
    get_ssh_config_ports() {
        echo "22"
        echo "2222"
    }
    
    # Вызываем тестируемую функцию и проверяем код возврата
    local exit_code
    _collect_ssh_ports_data
    exit_code=$?
    
    # Проверяем, что функция завершилась успешно
    assertEquals 0 $exit_code "Функция должна завершиться с кодом 0"
    
    # Проверяем, что глобальные переменные установлены правильно
    assertEquals "2222" "$COLLECTED_ACTIVE_PORTS" "Активные порты должны быть '2222'"
    assertEquals "22,2222" "$COLLECTED_CONFIG_PORTS" "Конфигурационные порты должны быть '22,2222'"
}

# Тест 7: когда конфигурационные порты содержат только один порт
test_collect_ssh_ports_data_single_config_port() {
    # Мокируем функцию _get_active_ssh_ports, чтобы она возвращала несколько портов
    _get_active_ssh_ports() {
        echo "22"
        echo "3333"
    }
    
    # Мокируем функцию get_ssh_config_ports, чтобы она возвращала один порт
    get_ssh_config_ports() {
        echo "2222"
    }
    
    # Вызываем тестируемую функцию и проверяем код возврата
    local exit_code
    _collect_ssh_ports_data
    exit_code=$?
    
    # Проверяем, что функция завершилась успешно
    assertEquals 0 $exit_code "Функция должна завершиться с кодом 0"
    
    # Проверяем, что глобальные переменные установлены правильно
    assertEquals "22,3333" "$COLLECTED_ACTIVE_PORTS" "Активные порты должны быть '22,3333'"
    assertEquals "2222" "$COLLECTED_CONFIG_PORTS" "Конфигурационные порты должны быть '2222'"
}

# Тест 8: когда порты возвращаются в разном порядке
test_collect_ssh_ports_data_ports_order() {
    # Мокируем функцию _get_active_ssh_ports, чтобы она возвращала порты в одном порядке
    _get_active_ssh_ports() {
        echo "3333"
        echo "22"
    }
    
    # Мокируем функцию get_ssh_config_ports, чтобы она возвращала порты в другом порядке
    get_ssh_config_ports() {
        echo "2222"
        echo "22"
    }
    
    # Вызываем тестируемую функцию и проверяем код возврата
    local exit_code
    _collect_ssh_ports_data
    exit_code=$?
    
    # Проверяем, что функция завершилась успешно
    assertEquals 0 $exit_code "Функция должна завершиться с кодом 0"
    
    # Проверяем, что глобальные переменные установлены правильно
    assertEquals "3333,22" "$COLLECTED_ACTIVE_PORTS" "Активные порты должны быть '3333,22'"
    assertEquals "2222,22" "$COLLECTED_CONFIG_PORTS" "Конфигурационные порты должны быть '2222,22'"
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
        test_collect_ssh_ports_data_no_active_ports || test_result=1
        test_collect_ssh_ports_data_no_config_ports || test_result=1
        test_collect_ssh_ports_data_matching_ports || test_result=1
        test_collect_ssh_ports_data_mismatching_ports || test_result=1
        test_collect_ssh_ports_data_custom_default_port || test_result=1
        test_collect_ssh_ports_data_single_active_port || test_result=1
        test_collect_ssh_ports_data_single_config_port || test_result=1
        test_collect_ssh_ports_data_ports_order || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _collect_ssh_ports_data"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_collect_ssh_ports_data_no_active_ports
            test_collect_ssh_ports_data_no_config_ports
            test_collect_ssh_ports_data_matching_ports
            test_collect_ssh_ports_data_mismatching_ports
            test_collect_ssh_ports_data_custom_default_port
            test_collect_ssh_ports_data_single_active_port
            test_collect_ssh_ports_data_single_config_port
            test_collect_ssh_ports_data_ports_order
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _collect_ssh_ports_data"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_collect_ssh_ports_data_no_active_ports
        test_collect_ssh_ports_data_no_config_ports
        test_collect_ssh_ports_data_matching_ports
        test_collect_ssh_ports_data_mismatching_ports
        test_collect_ssh_ports_data_custom_default_port
        test_collect_ssh_ports_data_single_active_port
        test_collect_ssh_ports_data_single_config_port
        test_collect_ssh_ports_data_ports_order
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi