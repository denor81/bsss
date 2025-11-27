#!/usr/bin/env bash

# Проверка прав root
check_root_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo "Этот скрипт требует прав root или sudo" >&2
        exit 1
    fi
}

# Проверка наличия systemd
check_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "Система не использует systemd. Выход." >&2
        exit 1
    fi
}

# Проверка доступности директории для записи
check_write_permission() {
    local dir="$1"
    if [[ ! -w "$dir" ]]; then
        echo "Нет прав на запись в директорию: $dir" >&2
        exit 1
    fi
}