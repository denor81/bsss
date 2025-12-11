#!/usr/bin/env bash
# tests/run_all_tests.sh
# Единый раннер для всех тестов в последовательном режиме

# ==========================================
# КОНФИГУРАЦИЯ РАННЕРА
# ==========================================
# Директория с тестами
TESTS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Функция для динамического обнаружения тестовых файлов
discover_test_files() {
    local test_files=()
    
    # Находим все файлы с префиксом test_ в директории тестов
    for file in "$TESTS_DIR"/test_*.sh; do
        # Проверяем, что файл существует (на случай, если нет файлов с таким шаблоном)
        if [[ -f "$file" ]]; then
            # Извлекаем только имя файла без пути
            local filename=$(basename "$file")
            test_files+=("$filename")
        fi
    done
    
    # Сортируем файлы по имени для последовательного выполнения
    IFS=$'\n' test_files=($(sort <<<"${test_files[*]}"))
    unset IFS
    
    # Возвращаем массив через глобальную переменную
    TEST_FILES=("${test_files[@]}")
}

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ==========================================

# Функция для вывода заголовка
print_header() {
    local title="$1"
    echo ""
    echo "=================================================="
    echo "$title"
    echo "=================================================="
}

# Функция для вывода разделителя
print_separator() {
    echo "--------------------------------------------------"
}

# Функция для запуска одного тестового файла
run_test_file() {
    local test_file="$1"
    local test_path="$TESTS_DIR/$test_file"
    
    # Проверяем существование файла теста
    if [[ ! -f "$test_path" ]]; then
        echo "[X] Файл теста не найден: $test_path"
        return 1
    fi
    
    # Проверяем, что файл исполняемый
    if [[ ! -x "$test_path" ]]; then
        echo "[X] Файл теста не исполняемый: $test_path"
        return 1
    fi
    
    # Запускаем тестовый файл и захватываем вывод
    local test_output
    test_output=$(TEST_RUNNER_MODE=1 bash "$test_path" 2>&1)
    local test_result=$?
    
    # Если тестовый файл завершился с ошибкой, выводим полный результат
    if [[ $test_result -ne 0 ]]; then
        print_header "Запуск теста: $test_file"
        echo "$test_output"
        echo "Тестовый файл $test_file завершился с кодом ошибки: $test_result"
        return $test_result
    fi
    
    # Анализируем вывод на наличие проваленных тестов
    local failed_tests
    failed_tests=$(echo "$test_output" | grep -c "^\[X\]" || true)
    
    # Если есть проваленные тесты, выводим полный результат
    if [[ $failed_tests -gt 0 ]]; then
        print_header "Запуск теста: $test_file"
        echo "$test_output"
        echo "Обнаружено $failed_tests проваленных тестов в $test_file"
        return 1
    fi
    
    # Если все тесты прошли успешно, выводим только галочку и имя файла
    echo "[✓] $test_file"
    
    # Иначе возвращаем успех
    return 0
}

# ==========================================
# ОСНОВНАЯ ФУНКЦИЯ ЗАПУСКА ТЕСТОВ
# ==========================================

# Функция для запуска всех тестов
run_all_tests() {
    # Сначала обнаруживаем все тестовые файлы
    discover_test_files
    local total_tests=${#TEST_FILES[@]}
    local passed_tests=0
    local failed_tests=0
    local test_results=()
    
    # Запускаем каждый тестовый файл последовательно
    for test_file in "${TEST_FILES[@]}"; do
        # Запускаем тестовый файл и сохраняем результат
        if run_test_file "$test_file"; then
            ((passed_tests++))
            test_results+=("$test_file: PASSED")
        else
            ((failed_tests++))
            test_results+=("$test_file: FAILED")
        fi
    done
    
    # Выводим итоговую статистику
    print_header "ИТОГИ ВЫПОЛНЕНИЯ ТЕСТОВ"
    echo "Всего тестовых файлов: $total_tests"
    echo "Успешно выполнено: $passed_tests"
    echo "Выполнено с ошибками: $failed_tests"
    
    # Выводим детальные результаты
    echo ""
    echo "Детальные результаты:"
    for result in "${test_results[@]}"; do
        echo "  - $result"
    done
    
    # Возвращаем общий результат (0 если все тесты прошли успешно)
    if [[ $failed_tests -eq 0 ]]; then
        print_header "ВСЕ ТЕСТЫ ПРОШЛИ УСПЕШНО"
        return 0
    else
        print_header "НЕКОТОРЫЕ ТЕСТЫ ЗАВЕРШИЛИСЬ С ОШИБКАМИ"
        return 1
    fi
}

# ==========================================
# ЗАПУСК РАННЕРА
# ==========================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Запускаем все тесты
    run_all_tests
    
    # Выходим с кодом результата выполнения всех тестов
    exit $?
fi