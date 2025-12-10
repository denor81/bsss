#!/usr/bin/env bash
# lib/common.sh
# ОБЩИЕ ФУНКЦИИ, ИСПОЛЬЗУЕМЫЕ В РАЗНЫХ ЧАСТЯХ ПРОЕКТА

# Добавляет путь в файл лога установки для последующего удаления
# TESTED: tests/test_add_uninstall_path.sh
_add_uninstall_path() {
    local uninstall_path="$1"
    local install_log_path="$INSTALL_DIR/$INSTALL_LOG_FILE_NAME"

    # Добавляем путь в файл лога, если его там еще нет
    if ! grep -Fxq "$uninstall_path" "$install_log_path" 2>/dev/null; then
        echo "$uninstall_path" >> "$install_log_path"
        log_info "Путь $uninstall_path добавлен в лог удаления $install_log_path"
    fi
    return 0
}