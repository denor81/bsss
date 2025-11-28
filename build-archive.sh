#!/usr/bin/env bash
# build-archive.sh
# Скрипт для создания архива проекта

set -euo pipefail

# Версия по умолчанию
VERSION="${1:-1.0.0}"

# Имя архива
ARCHIVE_NAME="project-v${VERSION}.tar.gz"

echo "[*] Создание архива ${ARCHIVE_NAME}..."

# Проверяем наличие необходимых файлов
if [[ ! -f "local-runner.sh" ]]; then
    echo "[!] Ошибка: файл local-runner.sh не найден" >&2
    exit 1
fi

if [[ ! -d "modules" ]]; then
    echo "[!] Ошибка: директория modules не найдена" >&2
    exit 1
fi

# Создаём архив
tar --exclude='.git' \
    --exclude='oneline-runner.sh' \
    --exclude='build-archive.sh' \
    --exclude='*.md' \
    --exclude='tests/' \
    -czf "${ARCHIVE_NAME}" \
    local-runner.sh \
    bsss-main.sh \
    modules/ \
    lib/ \
    templates/ 2>/dev/null || true

echo "[*] Архив ${ARCHIVE_NAME} создан успешно"

# Показываем содержимое архива
echo "[*] Содержимое архива:"
tar -tzf "${ARCHIVE_NAME}" | head -20

echo ""
echo "[*] Для публикации используйте команды:"
echo "git tag -a v${VERSION} -m \"Release version ${VERSION}\""
echo "git push origin v${VERSION}"
echo "gh release create v${VERSION} \"${ARCHIVE_NAME}\" --title \"Release v${VERSION}\""