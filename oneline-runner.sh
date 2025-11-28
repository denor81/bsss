#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/user/repo/main/oneline-runner.sh)

set -o pipefail

# Определение директории, где находится скрипт
# Обработка случая запуска через one-liner (bash <(curl ...))
if [[ -f "${0}" ]]; then
    # Обычный запуск из файла
    readonly SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
    readonly CONFIG_FILE="${SCRIPT_DIR}/config/bsss.conf"
else
    # Запуск через one-liner - используем временную директорию
    readonly SCRIPT_DIR="/tmp/bsss-config-$$"
    mkdir -p "$SCRIPT_DIR"
    
    # Скачиваем конфигурационный файл напрямую
    echo "[*] Загрузка конфигурации..."
    if ! curl -fsSL "https://raw.githubusercontent.com/denor81/bsss/main/config/bsss.conf" > "$SCRIPT_DIR/bsss.conf"; then
        echo "[!] Ошибка при загрузке конфигурационного файла" >&2
        rm -rf "$SCRIPT_DIR"
        exit 1
    fi
    
    # Устанавливаем очистку временной директории при выходе
    trap "rm -rf $SCRIPT_DIR" EXIT
    
    readonly CONFIG_FILE="${SCRIPT_DIR}/bsss.conf"
fi

# Загрузка конфигурации
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "[!] Конфигурационный файл не найден: $CONFIG_FILE" >&2
    exit 1
fi

echo "[*] Загрузка и распаковка проекта..."

# Проверяем наличие curl
if ! command -v curl &> /dev/null; then
    echo "[!] curl не установлен. Пожалуйста, установите curl." >&2
    exit 1
fi

# Проверяем наличие tar
if ! command -v tar &> /dev/null; then
    echo "[!] tar не установлен. Пожалуйста, установите tar." >&2
    exit 1
fi

# Создаём временную директорию
mkdir -p "$TEMP_PROJECT_DIR"
trap "rm -rf $TEMP_PROJECT_DIR" EXIT

# Функция проверки зависимостей
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v tar &> /dev/null; then
        missing_deps+=("tar")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "[!] Ошибка: не найдены зависимости: ${missing_deps[*]}" >&2
        echo "[*] Пожалуйста, установите недостающие зависимости и попробуйте снова." >&2
        exit 1
    fi
}

# Функция установки в систему
install_to_system() {
    local source_dir="$1"
    local version="$2"
    local install_dir="$INSTALL_DIR"
    local link_name="$BINARY_LINK_NAME"
    
    # Проверяем, установлен ли уже скрипт
    if [[ -d "$install_dir" ]]; then
        echo "[!] Скрипт уже установлен в системе."
        echo "[*] Для запуска используйте команду: sudo bsss"
        echo "[*] Для удаления выполните: sudo $install_dir/uninstall.sh"
        exit 0
    fi
    
    # Проверяем права root
    if [[ $EUID -ne 0 ]]; then
        echo "[!] Для установки в систему требуются права root." >&2
        echo "[*] Пожалуйста, запустите с sudo:" >&2
        echo "sudo bash <(curl -fsSL $ONELINE_INSTALL_URL)" >&2
        exit 1
    fi
    
    echo "[*] Устанавливаю BSSS в систему..."
    
    # Создаем директорию установки
    mkdir -p "$install_dir"
    
    # Копируем файлы
    cp -r "$source_dir"/* "$install_dir/"
    
    # Делаем скрипты исполняемыми
    chmod +x "$install_dir"/*.sh
    chmod -R +x "$install_dir"/modules
    
    # Создаем символическую ссылку с проверкой конфликта
    if [[ -L "$link_name" ]]; then
        echo "[!] Символическая ссылка $link_name уже существует."
        echo "[*] Она указывает на: $(readlink "$link_name")"
        
        # Предлагаем альтернативное имя
        local alt_link="$ALT_BINARY_LINK_NAME"
        read -p "Использовать альтернативное имя $alt_link? (Y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "[*] Установка отменена."
            rm -rf "$install_dir"
            exit 0
        else
            link_name="$alt_link"
        fi
    elif [[ -e "$link_name" ]]; then
        echo "[!] Файл $link_name уже существует и не является символической ссылкой."
        echo "[*] Установка отменена."
        rm -rf "$install_dir"
        exit 1
    fi
    
    # Создаем символическую ссылку
    ln -s "$install_dir/local-runner.sh" "$link_name"
    
    # Создаем скрипт удаления
    create_uninstall_script "$install_dir" "$link_name"
    
    echo "[*] Установка завершена!"
    echo "[*] Для запуска используйте команду: sudo $link_name"
    echo "[*] Для удаления выполните: sudo $install_dir/uninstall.sh"
}

# Функция создания скрипта удаления
create_uninstall_script() {
    local install_dir="$1"
    local link_name="$2"
    
    cat > "$install_dir/uninstall.sh" << EOF
#!/usr/bin/env bash
# uninstall.sh - Скрипт удаления BSSS

set -euo pipefail

INSTALL_DIR="$install_dir"
LINK_NAME="$link_name"

echo "[*] Удаление BSSS из системы..."

# Проверяем права root
if [[ \$EUID -ne 0 ]]; then
    echo "[!] Для удаления требуются права root." >&2
    echo "[*] Пожалуйста, запустите: sudo \$0" >&2
    exit 1
fi

# Удаляем символическую ссылку
if [[ -L "\$LINK_NAME" ]]; then
    rm "\$LINK_NAME"
    echo "[*] Символическая ссылка \$LINK_NAME удалена."
fi

# Удаляем директорию установки
if [[ -d "\$INSTALL_DIR" ]]; then
    rm -rf "\$INSTALL_DIR"
    echo "[*] Директория \$INSTALL_DIR удалена."
fi

echo "$BSSS_REMOVAL_COMPLETE"
EOF
    
    chmod +x "$install_dir/uninstall.sh"
}

# Спрашиваем пользователя о режиме запуска
echo "[*] Запустить bsss однократно?"
echo "Y - запуск однократно / n - установить / c - отмена"
read -p "Ваш выбор (Y/n/c): " -n 1 -r
echo

if [[ $REPLY =~ ^[Cc]$ ]]; then
    echo "[*] Отмена выполнения."
    exit 0
fi

check_dependencies

echo "[*] Получаю информацию о последнем релизе..."
RELEASE_INFO=$(curl -s "$RELEASE_API_URL")

# Извлекаем версию релиза
TAG_NAME=$(echo "$RELEASE_INFO" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)

if [[ -z "$TAG_NAME" ]]; then
    echo "[!] Не удалось получить версию релиза." >&2
    exit 1
fi

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
    install_to_system "$TEMP_PROJECT_DIR" "$TAG_NAME"
else
    # Разовый запуск
    echo "[*] Запускаю local-runner.sh..."
    
    # Запускаем локальный runner с передачей всех аргументов
    bash "$TEMP_PROJECT_DIR/local-runner.sh" "$@"
    
    exit_code=$?
    echo "[*] Готово!"
    exit $exit_code
fi