#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/user/repo/main/oneline-runner.sh)

set -euo pipefail

readonly LINK_NAME="bsss"
readonly INSTALL_DIR="/opt/bsss"
readonly TEMP_PROJECT_DIR="/tmp/bsss-$$"
readonly ERR_SUCCESS=0
readonly ERR_ALREADY_INSTALLED=1
readonly ERR_NO_ROOT=2
readonly ERR_USER_CANCEL=3

echo "[*] Загрузка и распаковка проекта..."

# Создаём/удаляем временную директорию
mkdir -p "$TEMP_PROJECT_DIR"
trap "rm -rf $TEMP_PROJECT_DIR" EXIT

# Функция установки в систему
install_to_system() {
    # Проверяем, установлен ли уже скрипт
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "[!] Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
        echo "[*] Для запуска Basic Server Security Setup используйте команду: sudo bsss, если не сработает - проверьте, что установлено в каталоге $INSTALL_DIR."
        echo "[*] Для удаления ранее установленного скрипта BSSS выполните: sudo bsss --uninstall"
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
        echo "[!] Символическая ссылка $LINK_NAME уже существует."
        echo "[*] Она указывает на: $(readlink "$LINK_NAME") - проверьте устанолен ли BSSS."
        return "$ERR_ALREADY_INSTALLED"
    fi
    
    # Создаем символическую ссылку
    ln -s "$INSTALL_DIR/local-runner.sh" "$LINK_NAME"
    
    echo "[*] Установка завершена!"
    echo "[*] Для запуска используйте команду: sudo $LINK_NAME"
    echo "[*] Для удаления выполните: sudo $LINK_NAME --uninstall"
}

# Спрашиваем пользователя о режиме запуска
echo "[*] Запустить bsss однократно?"
echo "Y - запуск однократно / n - установить / c - отмена"
read -p "Ваш выбор (Y/n/c): " -n 1 -r

if [[ $REPLY =~ ^[Cc]$ ]]; then
    echo "[*] Отмена выполнения."
    return "$ERR_USER_CANCEL"
fi

echo "[*] Получаю информацию о последнем релизе..."
RELEASE_INFO=$(curl -s "$RELEASE_API_URL")

# Формируем URL архива на основе версии
ARCHIVE_URL="https://github.com/${REPO_USER}/${REPO_NAME}/releases/download/${TAG_NAME}/project-${TAG_NAME}.tar.gz"

echo "[*] Скачиваю архив с GitHub: project-${TAG_NAME}.tar.gz"
if ! curl -Ls "$ARCHIVE_URL" | tar xz -C "$TEMP_PROJECT_DIR"; then
    echo "[!] Ошибка при скачивании или распаковке архива." >&2
    exit 1
fi

# Проверяем наличие local-runner.sh
if [[ ! -f "$TEMP_PROJECT_DIR/local-runner.sh" ]]; then
    echo "[!] Файл local-runner.sh не найден в архиве." >&2
    exit 1
fi

echo "[*] Архив успешно распакован."

# Обрабатываем выбор пользователя
if [[ $REPLY =~ ^[Nn]$ ]]; then
    # Установка в систему
    install_to_system
else
    # Разовый запуск
    echo "[*] Запускаю local-runner.sh..."
    
    # Запускаем локальный runner с передачей всех аргументов
    bash "$TEMP_PROJECT_DIR/local-runner.sh" "$@"
    
    exit_code=$?
    echo "[*] Готово!"
    exit $exit_code
fi

# Теперь используем обработчик ошибок с конструкцией case
handle_install_result() {
    local result=$?
    case $result in
        0)
            echo "[✔️] Установка прошла успешно!"
            ;;
        "$ERR_ALREADY_INSTALLED")
            echo "[❌] Уже установлен. Попробуйте удалить старую версию перед повторной установкой."
            ;;
        *)
            echo "[⚠️] Неизвестная ошибка ($result)"
            ;;
    esac
}

# Основной запуск
install_to_system
handle_install_result