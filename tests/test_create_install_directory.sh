#!/usr/bin/env bash
# tests/test_create_install_directory.sh
# Тест для функции _create_install_directory

# Подключаем тестируемый файл
# shellcheck source=../oneline-runner.sh
source "$(dirname "${BASH_SOURCE[0]}")/../oneline-runner.sh"
# Примечание: функции логирования и _add_uninstall_path уже определены в oneline-runner.sh

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

# Мокируем _add_uninstall_path, чтобы избежать побочных эффектов
_add_uninstall_path() {
    : # Ничего не делаем, подавляем вывод
}

# Вспомогательная функция для проверки истинности условия
assertTrue() {
    local condition="$1"
    local message="$2"
    
    if eval "$condition"; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message"
        return 1
    fi
}

# Вспомогательная функция для проверки ложности условия
assertFalse() {
    local condition="$1"
    local message="$2"
    
    if ! eval "$condition"; then
        echo "[V] $message"
        return 0
    else
        echo "[X] $message"
        return 1
    fi
}

# ==========================================
# ТЕСТЫ ФУНКЦИИ _create_install_directory
# ==========================================

# Тест 1: успешное создание директории
test_create_install_directory_success() {
    # Создаем временную директорию для теста с обработкой ошибок
    local test_dir
    test_dir=$(mktemp -d) || {
        echo "[X] Не удалось создать временную директорию для теста"
        return 1
    }
    
    # Определяем путь для создания директории
    local install_dir="$test_dir/test_install_dir"
    
    # Вызываем тестируемую функцию с параметром
    _create_install_directory "$install_dir"
    
    # Проверяем поведение вместо кода возврата: директория должна существовать
    assertTrue "[[ -d \"$install_dir\" ]]" "Директория $install_dir создана"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 2: создание директории с ошибкой (файл с таким же именем существует)
test_create_install_directory_file_exists() {
    # Создаем временную директорию для теста с обработкой ошибок
    local test_dir
    test_dir=$(mktemp -d) || {
        echo "[X] Не удалось создать временную директорию для теста"
        return 1
    }
    
    # Определяем путь для создания директории
    local install_dir="$test_dir/test_install_dir"
    
    # Создаем файл с таким же именем, как директория, которую мы пытаемся создать
    touch "$install_dir"
    
    # Вызываем тестируемую функцию с параметром, перенаправляя stderr, чтобы скрыть сообщение об ошибке mkdir
    _create_install_directory "$install_dir" 2>/dev/null
    
    # Проверяем поведение: файл не должен быть заменен директорией
    assertFalse "[[ -d \"$install_dir\" ]]" "Директория $install_dir не создана (файл существует)"
    assertTrue "[[ -f \"$install_dir\" ]]" "Файл $install_dir все еще существует"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 3: создание уже существующей директории
test_create_install_directory_already_exists() {
    # Создаем временную директорию для теста с обработкой ошибок
    local test_dir
    test_dir=$(mktemp -d) || {
        echo "[X] Не удалось создать временную директорию для теста"
        return 1
    }
    
    # Определяем путь для создания директории
    local install_dir="$test_dir/test_install_dir"
    
    # Создаем директорию заранее
    mkdir -p "$install_dir"
    
    # Вызываем тестируемую функцию с параметром
    _create_install_directory "$install_dir"
    
    # Проверяем поведение: директория все еще должна существовать
    assertTrue "[[ -d \"$install_dir\" ]]" "Директория $install_dir существует после повторного вызова"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 4: создание вложенной директории
test_create_install_directory_nested() {
    # Создаем временную директорию для теста с обработкой ошибок
    local test_dir
    test_dir=$(mktemp -d) || {
        echo "[X] Не удалось создать временную директорию для теста"
        return 1
    }
    
    # Создаем путь с вложенными директориями
    local nested_dir="$test_dir/level1/level2/level3"
    
    # Вызываем тестируемую функцию с параметром
    _create_install_directory "$nested_dir"
    
    # Проверяем поведение: все вложенные директории должны быть созданы
    assertTrue "[[ -d \"$nested_dir\" ]]" "Вложенная директория $nested_dir создана"
    
    # Проверяем, что и промежуточные директории созданы
    assertTrue "[[ -d \"$test_dir/level1\" ]]" "Промежуточная директория $test_dir/level1 создана"
    assertTrue "[[ -d \"$test_dir/level1/level2\" ]]" "Промежуточная директория $test_dir/level1/level2 создана"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 5: создание директории с путем, содержащим пробелы
test_create_install_directory_with_spaces() {
    # Создаем временную директорию для теста с обработкой ошибок
    local test_dir
    test_dir=$(mktemp -d) || {
        echo "[X] Не удалось создать временную директорию для теста"
        return 1
    }
    
    # Определяем путь с пробелами
    local install_dir="$test_dir/test install dir"
    
    # Вызываем тестируемую функцию с параметром
    _create_install_directory "$install_dir"
    
    # Проверяем поведение: директория с пробелами должна быть создана
    assertTrue "[[ -d \"$install_dir\" ]]" "Директория с пробелами $install_dir создана"
    
    # Удаляем временную директорию
    rm -rf "$test_dir"
}

# Тест 6: создание директории с пустым путем
test_create_install_directory_empty_path() {
    # Вызываем тестируемую функцию с пустым параметром
    _create_install_directory ""
    
    # Проверяем поведение: должна использоваться директория по умолчанию
    assertTrue "[[ -d \"$INSTALL_DIR\" ]]" "Директория по умолчанию $INSTALL_DIR создана"
    
    # Удаляем созданную директорию, если она существует
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi
}

# ==========================================
# ЗАПУСК ТЕСТОВ
# ==========================================
# Запускаем тесты только если файл вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Запуск тестов для функции _create_install_directory"
    echo "============================================="
    echo "Формат вывода: [V]/[X] [Описание теста]"
    echo "============================================="
    
    test_create_install_directory_success
    test_create_install_directory_file_exists
    test_create_install_directory_already_exists
    test_create_install_directory_nested
    test_create_install_directory_with_spaces
    test_create_install_directory_empty_path
    
    echo "============================================="
    echo "Тесты завершены"
fi