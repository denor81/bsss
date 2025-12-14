#!/usr/bin/env bash
# test_ssh-port_check_ssh_config_exists.sh
# Тест для функции check_ssh_config_exists из modules/04-ssh-port.sh

# ==========================================
# ПЕРЕМЕННЫЕ ДЛЯ ФАЙЛА ТЕСТА
# ==========================================

# Создаем временную директорию для тестов
TEST_DIR=$(mktemp -d)

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ТЕСТА
# ==========================================

# Очистка после тестов
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Моки для функций логирования
log_info() {
    # Ничего не делаем, просто поглощаем вызовы
    return 0
}

log_error() {
    # Ничего не делаем, просто поглощаем вызовы
    return 0
}

log_success() {
    # Ничего не делаем, просто поглощаем вызовы
    return 0
}

# Вспомогательная функция для сравнения результатов
assertEquals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [ "$expected" != "$actual" ]; then
        echo "[X] $message (ожидалось: $expected, получено: $actual)"
        return 1
    else
        echo "[V] $message"
        return 0
    fi
}

# ==========================================
# ПОДКЛЮЧЕНИЕ ТЕСТИРУЕМОГО МОДУЛЯ
# ==========================================

# Временно сохраняем текущие настройки
original_set_options=$(set +o)

# Временно отключаем строгий режим для тестов
set +e

# Подключаем тестируемый модуль
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

# Восстанавливаем настройки, но без -e (выход при ошибке)
eval "$original_set_options"
set +e

# ==========================================
# ТЕСТЫ ФУНКЦИИ check_ssh_config_exists
# ==========================================

# Тест 1: Функция возвращает 1 когда файлы не найдены
test_check_ssh_config_exists_no_files() {
    local config_dir="$TEST_DIR/empty"
    mkdir -p "$config_dir"
    
    # Вызываем функцию с тестовой директорией
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result=$?
    
    # Проверяем результат
    assertEquals 1 $result "Функция должна вернуть 1 когда файлы не найдены"
}

# Тест 2: Функция возвращает 0 когда файлы найдены
test_check_ssh_config_exists_files_found() {
    local config_dir="$TEST_DIR/with_files"
    mkdir -p "$config_dir"
    
    # Создаем тестовый файл
    touch "$config_dir/10-bsss-ssh-port.conf"
    
    # Вызываем функцию с тестовой директорией
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result=$?
    
    # Проверяем результат
    assertEquals 0 $result "Функция должна вернуть 0 когда файлы найдены"
}

# Тест 3: Функция работает с разными масками
test_check_ssh_config_exists_different_masks() {
    local config_dir="$TEST_DIR/mask_test"
    mkdir -p "$config_dir"
    
    # Создаем файл с другим именем
    touch "$config_dir/custom-ssh-config.conf"
    
    # Проверяем с маской, которая не должна найти файл
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result1=$?
    
    # Проверяем с маской, которая должна найти файл
    check_ssh_config_exists "$config_dir" "*custom-ssh-config.conf"
    local result2=$?
    
    # Проверяем результаты
    assertEquals 1 $result1 "Функция должна вернуть 1 для несовпадающей маски"
    assertEquals 0 $result2 "Функция должна вернуть 0 для совпадающей маски"
}

# Тест 4: Функция работает с путями, содержащими пробелы
test_check_ssh_config_exists_path_with_spaces() {
    local config_dir="$TEST_DIR/path with spaces"
    mkdir -p "$config_dir"
    
    # Создаем тестовый файл в директории с пробелами
    touch "$config_dir/10-bsss-ssh-port.conf"
    
    # Вызываем функцию с путем, содержащим пробелы
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result=$?
    
    # Проверяем результат
    assertEquals 0 $result "Функция должна вернуть 0 для пути с пробелами"
}

# Тест 5: Функция работает с путями, содержащими специальные символы
test_check_ssh_config_exists_path_with_special_chars() {
    local config_dir="$TEST_DIR/path-with_special.chars@123"
    mkdir -p "$config_dir"
    
    # Создаем тестовый файл в директории со специальными символами
    touch "$config_dir/10-bsss-ssh-port.conf"
    
    # Вызываем функцию с путем, содержащим специальные символы
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result=$?
    
    # Проверяем результат
    assertEquals 0 $result "Функция должна вернуть 0 для пути со специальными символами"
}

# Тест 6: Функция работает с путями, содержащими символы глоббинга
test_check_ssh_config_exists_path_with_globbing() {
    local config_dir="$TEST_DIR/path[with]globbing*chars"
    mkdir -p "$config_dir"
    
    # Создаем тестовый файл в директории с символами глоббинга
    touch "$config_dir/10-bsss-ssh-port.conf"
    
    # Вызываем функцию с путем, содержащим символы глоббинга
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result=$?
    
    # Проверяем результат
    assertEquals 0 $result "Функция должна вернуть 0 для пути с символами глоббинга"
}

# Тест 7: Функция работает с несуществующей директорией
test_check_ssh_config_exists_nonexistent_dir() {
    local config_dir="$TEST_DIR/nonexistent"
    
    # Вызываем функцию с несуществующей директорией
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result=$?
    
    # Проверяем результат
    assertEquals 1 $result "Функция должна вернуть 1 для несуществующей директории"
}

# Тест 8: Функция работает с маской, которая не найдет файлы
test_check_ssh_config_exists_non_matching_mask() {
    local config_dir="$TEST_DIR/non_matching_mask"
    mkdir -p "$config_dir"
    
    # Создаем тестовый файл
    touch "$config_dir/10-bsss-ssh-port.conf"
    
    # Вызываем функцию с маской, которая не найдет файлы
    check_ssh_config_exists "$config_dir" "*.nonexistent.conf"
    local result=$?
    
    # Проверяем результат
    assertEquals 1 $result "Функция должна вернуть 1 для маски, которая не найдет файлы"
}

# Тест 9: Функция работает с директорией без прав доступа
test_check_ssh_config_exists_no_permissions() {
    local config_dir="$TEST_DIR/no_permissions"
    mkdir -p "$config_dir"
    
    # Создаем тестовый файл
    touch "$config_dir/10-bsss-ssh-port.conf"
    
    # Убираем права на чтение для директории
    chmod 000 "$config_dir"
    
    # Вызываем функцию с директорией без прав доступа
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result=$?
    
    # Восстанавливаем права для очистки
    chmod 755 "$config_dir"
    
    # Проверяем результат с учетом того, что root имеет доступ к файлам независимо от прав
    if [[ $(id -u) -eq 0 ]]; then
        # При запуске от root ожидаем, что файлы будут найдены
        assertEquals 0 $result "Функция должна вернуть 0 при запуске от root (доступ к файлам есть)"
    else
        # При запуске от обычного пользователя ожидаем, что файлы не будут найдены
        assertEquals 1 $result "Функция должна вернуть 1 для директории без прав доступа"
    fi
}

# Тест 10: Функция работает с несколькими файлами
test_check_ssh_config_exists_multiple_files() {
    local config_dir="$TEST_DIR/multiple_files"
    mkdir -p "$config_dir"
    
    # Создаем несколько тестовых файлов
    touch "$config_dir/10-bsss-ssh-port.conf"
    touch "$config_dir/20-bsss-ssh-port.conf"
    
    # Вызываем функцию с тестовой директорией
    check_ssh_config_exists "$config_dir" "*bsss-ssh-port.conf"
    local result=$?
    
    # Проверяем результат
    assertEquals 0 $result "Функция должна вернуть 0 когда найдено несколько файлов"
}

# Тест 11: Функция работает с символическими ссылками
test_check_ssh_config_exists_symlinks() {
    local config_dir="$TEST_DIR/symlinks"
    local target_dir="$TEST_DIR/target_dir"
    mkdir -p "$config_dir"
    mkdir -p "$target_dir"
    
    # Создаем тестовый файл в целевой директории
    touch "$target_dir/10-bsss-ssh-port.conf"
    
    # Создаем символическую ссылку на файл
    ln -s "$target_dir/10-bsss-ssh-port.conf" "$config_dir/symlink.conf"
    
    # Вызываем функцию с директорией, содержащей символическую ссылку
    check_ssh_config_exists "$config_dir" "*symlink.conf"
    local result=$?
    
    # Проверяем результат - символические ссылки не являются обычными файлами
    assertEquals 1 $result "Функция должна вернуть 1 для символической ссылки (не является обычным файлом)"
    
    # Теперь создадим обычный файл для проверки
    touch "$config_dir/regular-file.conf"
    
    # Вызываем функцию с директорией, содержащей обычный файл
    check_ssh_config_exists "$config_dir" "*regular-file.conf"
    local result2=$?
    
    # Проверяем результат
    assertEquals 0 $result2 "Функция должна вернуть 0 для обычного файла"
}

# Тест 12: Функция работает с файлом вместо директории
test_check_ssh_config_exists_file_instead_of_dir() {
    local config_file="$TEST_DIR/not_a_dir.conf"
    
    # Создаем файл вместо директории
    touch "$config_file"
    
    # Вызываем функцию с путем к файлу вместо директории
    # Примечание: find может обрабатывать файлы как пути для поиска
    check_ssh_config_exists "$config_file" "*.conf"
    local result=$?
    
    # Проверяем результат - find может найти файл, если он соответствует маске
    # Это ожидаемое поведение функции find
    assertEquals 0 $result "Функция должна вернуть 0 когда файл соответствует маске поиска"
}

# Тест 13: Функция работает с параметрами по умолчанию
test_check_ssh_config_exists_default_params() {
    # Создаем директорию с файлом, соответствующим маске по умолчанию
    local config_dir="$TEST_DIR/default_params"
    mkdir -p "$config_dir"
    
    # Создаем файл, соответствующий маске по умолчанию
    touch "$config_dir/10-bsss-ssh-port.conf"
    
    # Вызываем функцию без второго параметра (должен использоваться SSH_CONFIG_FILE_MASK)
    check_ssh_config_exists "$config_dir"
    local result=$?
    
    # Проверяем результат
    assertEquals 0 $result "Функция должна вернуть 0 при использовании маски по умолчанию"
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
        test_check_ssh_config_exists_no_files || test_result=1
        test_check_ssh_config_exists_files_found || test_result=1
        test_check_ssh_config_exists_different_masks || test_result=1
        test_check_ssh_config_exists_path_with_spaces || test_result=1
        test_check_ssh_config_exists_path_with_special_chars || test_result=1
        test_check_ssh_config_exists_path_with_globbing || test_result=1
        test_check_ssh_config_exists_nonexistent_dir || test_result=1
        test_check_ssh_config_exists_non_matching_mask || test_result=1
        test_check_ssh_config_exists_no_permissions || test_result=1
        test_check_ssh_config_exists_multiple_files || test_result=1
        test_check_ssh_config_exists_symlinks || test_result=1
        test_check_ssh_config_exists_file_instead_of_dir || test_result=1
        test_check_ssh_config_exists_default_params || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции check_ssh_config_exists из modules/04-ssh-port.sh"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] (ожидалось: X, получено: Y)"
            echo "============================================="
            
            test_check_ssh_config_exists_no_files
            test_check_ssh_config_exists_files_found
            test_check_ssh_config_exists_different_masks
            test_check_ssh_config_exists_path_with_spaces
            test_check_ssh_config_exists_path_with_special_chars
            test_check_ssh_config_exists_path_with_globbing
            test_check_ssh_config_exists_nonexistent_dir
            test_check_ssh_config_exists_non_matching_mask
            test_check_ssh_config_exists_no_permissions
            test_check_ssh_config_exists_multiple_files
            test_check_ssh_config_exists_symlinks
            test_check_ssh_config_exists_file_instead_of_dir
            test_check_ssh_config_exists_default_params
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции check_ssh_config_exists из modules/04-ssh-port.sh"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] (ожидалось: X, получено: Y)"
        echo "============================================="
        
        test_check_ssh_config_exists_no_files
        test_check_ssh_config_exists_files_found
        test_check_ssh_config_exists_different_masks
        test_check_ssh_config_exists_path_with_spaces
        test_check_ssh_config_exists_path_with_special_chars
        test_check_ssh_config_exists_path_with_globbing
        test_check_ssh_config_exists_nonexistent_dir
        test_check_ssh_config_exists_non_matching_mask
        test_check_ssh_config_exists_no_permissions
        test_check_ssh_config_exists_multiple_files
        test_check_ssh_config_exists_symlinks
        test_check_ssh_config_exists_file_instead_of_dir
        test_check_ssh_config_exists_default_params
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi