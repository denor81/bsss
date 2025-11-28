#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/user/repo/main/oneline-runner.sh)

set -euo pipefail

# Константы
REPO_USER="your-github-username"
REPO_NAME="your-repo-name"
RELEASE_URL="https://github.com/${REPO_USER}/${REPO_NAME}/releases/latest/download/project.tar.gz"
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

echo "[*] Скачиваю архив с GitHub..."
if ! curl -Ls "$RELEASE_URL" | tar xz -C "$PROJECT_DIR"; then
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