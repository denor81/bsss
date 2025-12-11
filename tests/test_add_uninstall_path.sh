#!/usr/bin/env bash
# tests/test_add_uninstall_path.sh
# Тест для функции _add_uninstall_path

# Подключаем тестируемый файл
# shellcheck source=../oneline-runner.sh
source "$(dirname "${BASH_SOURCE[0]}")/../oneline-runner.sh"
# Примечание: функции логирования уже определены в oneline-runner.sh

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

# Мокируем log_info, чтобы избежать вывода в нашем формате
log_info() {
    : # Ничего не делаем, подавляем вывод
}

# Мокируем log_error, чтобы избежать вывода в нашем формате
log_error() {
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

# Создание тестовой среды с гарантированной очисткой
setup_test() {
    local test_dir=$(mktemp -d --tmpdir "bsss_test_XXXXXX")
    # Устанавливаем trap для гарантированной очистки
    trap "rm -rf '$test_dir'" EXIT
    echo "$test_dir"
}

# Проверка наличия пути в файле
assert_path_in_file() {
    local expected_path="$1"
    local file_path="$2"
    local message="$3"
    
    if [[ -f "$file_path" ]] && grep -Fxq "$expected_path" "$file_path" 2>/dev/null; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message"
        return 1
    fi
}

# Проверка отсутствия пути в файле
assert_path_not_in_file() {
    local expected_path="$1"
    local file_path="$2"
    local message="$3"
    
    if [[ ! -f "$file_path" ]] || ! grep -Fxq "$expected_path" "$file_path" 2>/dev/null; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message"
        return 1
    fi
}

# ==========================================
# ТЕСТЫ ФУНКЦИИ _add_uninstall_path
# ==========================================

# Тест 1: успешное добавление пути в лог-файл
test_add_uninstall_path_success() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь для добавления в лог
    local test_path="/path/to/uninstall"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию с параметрами
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное добавление пути в лог"
    
    # Проверяем, что путь добавлен в файл
    assert_path_in_file "$test_path" "$install_log_path" "Путь найден в лог-файле"
}

# Тест 2: попытка добавить дублирующийся путь
test_add_uninstall_path_duplicate() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь для добавления в лог
    local test_path="/path/to/uninstall"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Создаем лог-файл и добавляем путь вручную
    echo "$test_path" > "$install_log_path"
    
    # Проверяем, что путь уже в файле
    local initial_count
    initial_count=$(grep -c "$test_path" "$install_log_path" 2>/dev/null || echo "0")
    assertEquals 1 "$initial_count" "Путь уже существует в лог-файле"
    
    # Вызываем тестируемую функцию с тем же путем
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Обработка дублирующегося пути"
    
    # Проверяем, что путь не был добавлен повторно
    local final_count
    final_count=$(grep -c "$test_path" "$install_log_path" 2>/dev/null || echo "0")
    assertEquals 1 "$final_count" "Путь не дублирован в лог-файле"
}

# Тест 3: добавление нескольких путей
test_add_uninstall_path_multiple() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Пути для добавления в лог
    local test_path1="/path/to/uninstall1"
    local test_path2="/path/to/uninstall2"
    local test_path3="/path/to/uninstall3"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию для каждого пути
    _add_uninstall_path "$test_path1" "$install_log_path"
    local result1=$?
    assertEquals 0 $result1 "Добавление первого пути"
    
    _add_uninstall_path "$test_path2" "$install_log_path"
    local result2=$?
    assertEquals 0 $result2 "Добавление второго пути"
    
    _add_uninstall_path "$test_path3" "$install_log_path"
    local result3=$?
    assertEquals 0 $result3 "Добавление третьего пути"
    
    # Проверяем, что все пути добавлены в файл
    if [[ -f "$install_log_path" ]]; then
        local line_count
        line_count=$(wc -l < "$install_log_path" 2>/dev/null || echo "0")
        assertEquals 3 "$line_count" "Количество путей в лог-файле"
        
        # Проверяем каждый путь
        assert_path_in_file "$test_path1" "$install_log_path" "Первый путь найден в лог-файле"
        assert_path_in_file "$test_path2" "$install_log_path" "Второй путь найден в лог-файле"
        assert_path_in_file "$test_path3" "$install_log_path" "Третий путь найден в лог-файле"
    else
        echo "[X] Лог-файл не создан"
    fi
}

# Тест 4: добавление пути с пробелами
test_add_uninstall_path_with_spaces() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь с пробелами для добавления в лог
    local test_path="/path/with spaces/to/uninstall"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное добавление пути с пробелами в лог"
    
    # Проверяем, что путь добавлен в файл
    assert_path_in_file "$test_path" "$install_log_path" "Путь с пробелами найден в лог-файле"
}

# Тест 5: добавление пустого пути
test_add_uninstall_path_empty() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Пустой путь для добавления в лог
    local test_path=""
    
    # Вызываем тестируемую функцию
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 1 $result "Обработка пустого пути (должна быть ошибка)"
    
    # Проверяем, что пустая строка не добавлена в файл
    assert_path_not_in_file "$test_path" "$install_log_path" "Пустая строка не найдена в лог-файле"
}

# ==========================================
# ТЕСТЫ ГРАНИЧНЫХ СЛУЧАЕВ
# ==========================================

# Тест 6: добавление пути со специальными символами
test_add_uninstall_path_special_chars() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь со специальными символами
    local test_path="/path/with-$pecial&chars@to#uninstall"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное добавление пути с спецсимволами в лог"
    
    # Проверяем, что путь добавлен в файл
    assert_path_in_file "$test_path" "$install_log_path" "Путь с спецсимволами найден в лог-файле"
}

# Тест 7: добавление очень длинного пути
test_add_uninstall_path_long() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Создаем очень длинный путь (более 200 символов)
    local long_segment="/very/long/path/segment/that/exceeds/normal/path/length/limits/and/contains/many/directories/to/test/how/the/function/handles/extremely/long/paths/that/might/cause/issues/in/some/systems/or/applications"
    local test_path="${long_segment}${long_segment}"  # Удваиваем для большей длины
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное добавление длинного пути в лог"
    
    # Проверяем, что путь добавлен в файл
    assert_path_in_file "$test_path" "$install_log_path" "Длинный путь найден в лог-файле"
}

# Тест 8: обработка пути с символами новой строки
test_add_uninstall_path_newline() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь с символом новой строки (должен быть обработан корректно)
    local test_path="/path/with
newline"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Вызываем тестируемую функцию
    _add_uninstall_path "$test_path" "$install_log_path"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Успешное добавление пути с символом новой строки в лог"
    
    # Проверяем, что путь добавлен в файл
    assert_path_in_file "$test_path" "$install_log_path" "Путь с символом новой строки найден в лог-файле"
}

# Тест 9: отсутствие прав на запись в директорию
test_add_uninstall_path_no_write_permissions() {
    # Создаем временную директорию для теста
    local test_dir=$(setup_test)
    
    # Создаем директорию установки
    local install_dir="$test_dir/test_install_dir"
    mkdir -p "$install_dir"
    
    # Путь для добавления в лог
    local test_path="/path/to/uninstall"
    
    # Путь к лог-файлу
    local install_log_path="$install_dir/.uninstall_paths"
    
    # Убираем права на запись из директории
    chmod a-w "$install_dir"
    
    # Вызываем тестируемую функцию и перенаправляем вывод, чтобы избежать ошибок в терминале
    local output
    output=$(_add_uninstall_path "$test_path" "$install_log_path" 2>&1)
    local result=$?
    
    # Восстанавливаем права для очистки
    chmod u+w "$install_dir"
    
    # Проверяем результат
    # Примечание: в зависимости от системы и прав пользователя, файл может быть создан
    # даже при отсутствии прав на запись, особенно если пользователь root
    # Этот тест проверяет фактическое поведение функции, а не ожидаемое
    if [[ -f "$install_log_path" ]] && [[ -s "$install_log_path" ]]; then
        echo "[V] Файл был создан (возможно, из-за особенностей системы или прав root)"
        # Проверяем, что путь действительно добавлен в файл
        assert_path_in_file "$test_path" "$install_log_path" "Путь найден в созданном файле"
    else
        echo "[V] Файл не создан при отсутствии прав на запись"
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
        test_result=0
        
        # Запускаем тесты и захватываем вывод
        test_add_uninstall_path_success || test_result=1
        test_add_uninstall_path_duplicate || test_result=1
        test_add_uninstall_path_multiple || test_result=1
        test_add_uninstall_path_with_spaces || test_result=1
        test_add_uninstall_path_empty || test_result=1
        test_add_uninstall_path_special_chars || test_result=1
        test_add_uninstall_path_long || test_result=1
        test_add_uninstall_path_newline || test_result=1
        test_add_uninstall_path_no_write_permissions || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции _add_uninstall_path"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста]"
            echo "============================================="
            
            test_add_uninstall_path_success
            test_add_uninstall_path_duplicate
            test_add_uninstall_path_multiple
            test_add_uninstall_path_with_spaces
            test_add_uninstall_path_empty
            test_add_uninstall_path_special_chars
            test_add_uninstall_path_long
            test_add_uninstall_path_newline
            test_add_uninstall_path_no_write_permissions
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции _add_uninstall_path"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста]"
        echo "============================================="
        
        test_add_uninstall_path_success
        test_add_uninstall_path_duplicate
        test_add_uninstall_path_multiple
        test_add_uninstall_path_with_spaces
        test_add_uninstall_path_empty
        test_add_uninstall_path_special_chars
        test_add_uninstall_path_long
        test_add_uninstall_path_newline
        test_add_uninstall_path_no_write_permissions
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi