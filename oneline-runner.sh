#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh)

set -euo pipefail

readonly ARCHIVE_URL="https://github.com/denor81/bsss/archive/refs/tags/v1.0.0.tar.gz"
readonly LINK_NAME="bsss"
readonly INSTALL_DIR="/opt/bsss"
readonly TEMP_PROJECT_DIR="/tmp/bsss-$$"
readonly ERR_SUCCESS=0
readonly ERR_ALREADY_INSTALLED=1
readonly ERR_NO_ROOT=2
readonly ERR_UNPACK=3

echo "[*] Загрузка и распаковка проекта..."

# Создаём/удаляем временную директорию
mkdir -p "$TEMP_PROJECT_DIR"
# trap "rm -rf $TEMP_PROJECT_DIR" EXIT

echo "[*] Создана временная директория $TEMP_PROJECT_DIR"

# Функция установки в систему
install_to_system() {
    # Проверяем, установлен ли уже скрипт
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "[!] Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога." >&2
        echo "[*] Для запуска Basic Server Security Setup используйте команду: sudo bsss, если не сработает - проверьте, что установлено в каталоге $INSTALL_DIR." >&2
        echo "[*] Для удаления ранее установленного скрипта BSSS выполните: sudo bsss --uninstall" >&2
        return "$ERR_ALREADY_INSTALLED"
    fi
    
    # Проверяем права root
    if [[ $EUID -ne 0 ]]; then
        echo "[!] Для установки в систему требуются права root." >&2
        echo "[*] Пожалуйста, запустите $$0 с sudo" >&2
        return "$ERR_NO_ROOT"
    fi
    
    echo "[*] Устанавливаю BSSS в систему..."
    
    # Создаем директорию установки
    mkdir -p "$INSTALL_DIR"
    
    # Копируем файлы
    cp -r "$TEMP_PROJECT_DIR"/* "$INSTALL_DIR/"
    
    # Делаем скрипты исполняемыми
    chmod +x "$INSTALL_DIR"/*.sh
    chmod -R +x "$INSTALL_DIR"/modules
    
    # Создаем символическую ссылку с проверкой конфликта
    if [[ -L "$LINK_NAME" ]]; then
        echo "[!] Символическая ссылка $LINK_NAME уже существует." >&2
        echo "[*] Она указывает на: $(readlink "$LINK_NAME") - проверьте устанолен ли BSSS." >&2
        return "$ERR_ALREADY_INSTALLED"
    fi
    
    # Создаем символическую ссылку
    ln -s "$INSTALL_DIR/local-runner.sh" "$LINK_NAME"
    
    echo "[*] Установка завершена!"
    echo "[*] Для запуска используйте команду: sudo $LINK_NAME"
    echo "[*] Для удаления выполните: sudo $LINK_NAME --uninstall"
    return "$ERR_SUCCESS"
}

# Спрашиваем пользователя о режиме запуска
echo "[*] Запустить bsss однократно?"
echo "Y - запуск однократно / n - установить / c - отмена"
read -p "Ваш выбор (Y/n/c): " -n 1 -r

if [[ $REPLY =~ ^[Cc]$ ]]; then
    echo "[*] Отмена выполнения."
    return "$ERR_SUCCESS"
fi

echo "[*] Скачиваю архив с GitHub: $ARCHIVE_URL"
if ! curl -Ls "$ARCHIVE_URL" | tar xz -C "$TEMP_PROJECT_DIR"; then
    echo "[!] Ошибка при скачивании или распаковке архива." >&2
    return "$ERR_UNPACK"
fi

# Проверяем наличие local-runner.sh
if [[ ! -f "$TEMP_PROJECT_DIR/local-runner.sh" ]]; then
    echo "[!] Файл local-runner.sh не найден в архиве." >&2
    return "$ERR_UNPACK"
fi

echo "[*] Архив успешно распакован."

# Обрабатываем выбор пользователя
if [[ $REPLY =~ ^[Nn]$ ]]; then
    # Установка в систему
    install_to_system
else
    # Разовый запуск
    echo "[*] Запускаю local-runner.sh из временной директории $TEMP_PROJECT_DIR"
    
    # Запускаем локальный runner с передачей всех аргументов
    # Всегда вернет 0 или сам прекратит выполнение
    bash "$TEMP_PROJECT_DIR/local-runner.sh" "$@"
fi

# Теперь используем обработчик ошибок с конструкцией case
handle_install_result() {
    local result=$?
    case $result in
        "$ERR_SUCCESS") echo "[OK] Установка прошла успешно!" ;;
        "$ERR_ALREADY_INSTALLED") echo "[ERR] Уже установлен. Попробуйте удалить старую версию перед повторной установкой."  >&2 ;;
        "$ERR_NO_ROOT") echo "[ERR] Нет root прав."  >&2 ;;
        "$ERR_UNPACK") echo "[ERR] Ошибка скачивания или распаковки"  >&2 ;;
        *) echo "[ERR] Неизвестная ошибка ($result)" >&2 ;;
    esac
}

handle_install_result