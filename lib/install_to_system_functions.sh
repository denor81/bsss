#!/usr/bin/env bash
# lib/install_to_system_functions.sh
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ УСТАНОВКИ

# Подключаем общие функции
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Функция теперь может работать как с дефолтами, так и с переданными параметрами
# TESTED: tests/test_check_symlink_exists.sh
_check_symlink_exists() {
    if [[ -L "$SYMBOL_LINK_PATH" ]]; then
        log_error "Символическая ссылка $UTIL_NAME уже существует"
        return 1
    fi
    return 0
}

# Создание директории установки
# TESTED: tests/test_create_install_directory.sh
_create_install_directory() {
    log_info "Создаю директорию $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR" || {
        log_error "Не удалось создать директорию $INSTALL_DIR"
        return 1
    }
    _add_uninstall_path "$INSTALL_DIR"
    return 0
}

# Копирование файлов установки
# TESTED: tests/test_copy_installation_files.sh
_copy_installation_files() {
    local tmp_dir_path=$(dirname "$TMP_LOCAL_RUNNER_PATH")
    log_info "Копирую файлы из $tmp_dir_path в $INSTALL_DIR"
    
    cp -r "$tmp_dir_path"/* "$INSTALL_DIR/" || {
        log_error "Не удалось скопировать файлы"
        return 1
    }
    return 0
}

# Создание символической ссылки
# TESTED: tests/test_create_symlink.sh
_create_symlink() {
    local local_runner_path="$INSTALL_DIR/$LOCAL_RUNNER_FILE_NAME"
    
    ln -s "$local_runner_path" "$SYMBOL_LINK_PATH" || {
        log_error "Не удалось создать символическую ссылку"
        return 1
    }
    
    log_info "Создана символическая ссылка $UTIL_NAME для запуска $local_runner_path. (Расположение ссылки: $(dirname "$SYMBOL_LINK_PATH"))"
    _add_uninstall_path "$SYMBOL_LINK_PATH"
    return 0
}

# Установка прав на выполнение
# TESTED: tests/test_set_execution_permissions.sh
_set_execution_permissions() {
    log_info "Устанавливаю права запуска (+x) в $INSTALL_DIR для .sh файлов"
    chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null
    # Возвращаем 0 даже если нет .sh файлов - это нормально
    return 0
}