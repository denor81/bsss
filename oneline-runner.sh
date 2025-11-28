#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/user/repo/main/oneline-runner.sh)

set -euo pipefail

# Константы
REPO_USER="denor81"
REPO_NAME="bsss"
# Получаем информацию о последнем релизе
RELEASE_API_URL="https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/releases/latest"
PROJECT_DIR="/tmp/bsss-$$"

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
mkdir -p "$PROJECT_DIR"
trap "rm -rf $PROJECT_DIR" EXIT

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
if ! curl -Ls "$ARCHIVE_URL" | tar xz -C "$PROJECT_DIR"; then
    echo "[!] Ошибка при скачивании или распаковке архива." >&2
    exit 1
fi

# Проверяем наличие local-runner.sh
if [[ ! -f "$PROJECT_DIR/local-runner.sh" ]]; then
    echo "[!] Файл local-runner.sh не найден в архиве." >&2
    exit 1
fi

echo "[*] Архив успешно распакован."
echo "[*] Запускаю local-runner.sh..."

# Запускаем локальный runner с передачей всех аргументов
bash "$PROJECT_DIR/local-runner.sh" "$@"

exit_code=$?
echo "[*] Готово!"
exit $exit_code