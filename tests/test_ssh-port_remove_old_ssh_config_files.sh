#!/usr/bin/env bash
# tests/test_remove_old_ssh_config_files.sh
# Тест для функции remove_old_ssh_config_files

# Подключаем тестируемый файл
# shellcheck source=../modules/04-ssh-port.sh
source "$(dirname "${BASH_SOURCE[0]}")/../modules/04-ssh-port.sh"

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
# ТЕСТЫ ФУНКЦИИ remove_old_ssh_config_files
# ==========================================

# Тест 1: когда старые конфигурационные файлы не существуют
test_remove_old_ssh_config_files_no_files() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию с параметрами
    remove_old_ssh_config_files "$test_dir" "*bsss-ssh-port.conf"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файлы не найдены"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: когда старые конфигурационные файлы существуют и должны быть удалены
test_remove_old_ssh_config_files_with_files() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовые конфигурационные файлы
    touch "$test_dir/old-bsss-ssh-port.conf"
    touch "$test_dir/another-bsss-ssh-port.conf"
    touch "$test_dir/not-matching-file.txt"
    
    # Вызываем тестируемую функцию с параметрами
    remove_old_ssh_config_files "$test_dir" "*bsss-ssh-port.conf"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Файлы успешно удалены"
    
    # Проверяем, что нужные файлы удалены, а не совпадающие по маске - остались
    local file_exists_old=$(test -f "$test_dir/old-bsss-ssh-port.conf"; echo $?)
    local file_exists_another=$(test -f "$test_dir/another-bsss-ssh-port.conf"; echo $?)
    local file_exists_not_matching=$(test -f "$test_dir/not-matching-file.txt"; echo $?)
    
    assertEquals 1 $file_exists_old "Файл old-bsss-ssh-port.conf удален"
    assertEquals 1 $file_exists_another "Файл another-bsss-ssh-port.conf удален"
    assertEquals 0 $file_exists_not_matching "Файл not-matching-file.txt не удален"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: когда директория не существует
test_remove_old_ssh_config_files_no_directory() {
    # Используем несуществующий путь
    local nonexistent_dir="/tmp/nonexistent_dir_$(date +%s)"
    
    # Вызываем тестируемую функцию с параметрами
    remove_old_ssh_config_files "$nonexistent_dir" "*bsss-ssh-port.conf"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Директория не существует"
}

# Тест 4: проверка с файлом, который не может быть удален (ошибка прав доступа)
test_remove_old_ssh_config_files_readonly_file() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовый конфигурационный файл
    touch "$test_dir/readonly-bsss-ssh-port.conf"
    
    # Мокируем команду rm, чтобы симулировать ошибку удаления
    rm() {
        if [[ "$1" == "-f" && "$2" == *"readonly-bsss-ssh-port.conf"* ]]; then
            # Симулируем ошибку удаления
            return 1
        else
            # Для остальных файлов используем настоящую команду rm
            /bin/rm "$@"
        fi
    }
    
    # Вызываем тестируемую функцию с параметрами
    remove_old_ssh_config_files "$test_dir" "*bsss-ssh-port.conf"
    
    # Восстанавливаем настоящую команду rm
    unset rm
    
    # Проверяем результат (функция должна завершиться с кодом 0, даже если не удалось удалить файл)
    local result=$?
    assertEquals 0 $result "Файл с правами только для чтения"
    
    # Проверяем, что файл все еще существует (не был удален из-за ошибки)
    assertEquals 0 $(test -f "$test_dir/readonly-bsss-ssh-port.conf"; echo $?) "Файл с ошибкой удаления не удален"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: проверка с пустой директорией
test_remove_old_ssh_config_files_empty_directory() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Вызываем тестируемую функцию с параметрами
    remove_old_ssh_config_files "$test_dir" "*bsss-ssh-port.conf"
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Пустая директория"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 6: проверка с пустой маской
test_remove_old_ssh_config_files_empty_mask() {
    # Создаем временную директорию для теста
    local test_dir=$(mktemp -d)
    
    # Создаем тестовые файлы
    touch "$test_dir/file1.conf"
    touch "$test_dir/file2.txt"
    
    # Вызываем тестируемую функцию с пустой маской
    remove_old_ssh_config_files "$test_dir" ""
    
    # Проверяем результат
    local result=$?
    assertEquals 0 $result "Пустая маска"
    
    # Проверяем, что файлы не были удалены
    assertEquals 0 $(test -f "$test_dir/file1.conf"; echo $?) "Файл file1.conf не удален"
    assertEquals 0 $(test -f "$test_dir/file2.txt"; echo $?) "Файл file2.txt не удален"
    
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
        test_remove_old_ssh_config_files_no_files || test_result=1
        test_remove_old_ssh_config_files_with_files || test_result=1
        test_remove_old_ssh_config_files_no_directory || test_result=1
        test_remove_old_ssh_config_files_readonly_file || test_result=1
        test_remove_old_ssh_config_files_empty_directory || test_result=1
        test_remove_old_ssh_config_files_empty_mask || test_result=1
        
        # Если есть ошибки, выводим полный отчет
        if [[ $test_result -ne 0 ]]; then
            echo "Запуск тестов для функции remove_old_ssh_config_files"
            echo "============================================="
            echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
            echo "============================================="
            
            test_remove_old_ssh_config_files_no_files
            test_remove_old_ssh_config_files_with_files
            test_remove_old_ssh_config_files_no_directory
            test_remove_old_ssh_config_files_readonly_file
            test_remove_old_ssh_config_files_empty_directory
            test_remove_old_ssh_config_files_empty_mask
            
            echo "============================================="
            echo "Тесты завершены с ошибками"
        fi
        
        exit $test_result
    else
        # Прямой запуск - всегда выводим полный отчет
        echo "Запуск тестов для функции remove_old_ssh_config_files"
        echo "============================================="
        echo "Формат вывода: [V]/[X] [Описание теста] [Ожидаемый результат]/[Полученный результат]"
        echo "============================================="
        
        test_remove_old_ssh_config_files_no_files
        test_remove_old_ssh_config_files_with_files
        test_remove_old_ssh_config_files_no_directory
        test_remove_old_ssh_config_files_readonly_file
        test_remove_old_ssh_config_files_empty_directory
        test_remove_old_ssh_config_files_empty_mask
        
        echo "============================================="
        echo "Тесты завершены"
    fi
fi