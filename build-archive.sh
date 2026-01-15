#!/usr/bin/env bash
# build-archive.sh
# Скрипт для создания архива проекта

set -euo pipefail

# @type:        Orchestrator
# @description: Создает архив проекта
# @params:
#   version     [optional] Версия архива (default: 1.0.0)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка создания архива
main() {
    # Версия по умолчанию
    VERSION="${1:-1.0.0}"

    # Имя архива
    ARCHIVE_NAME="project-v${VERSION}.tar.gz"

    echo "[ ] Создание архива ${ARCHIVE_NAME}..."

    # Создаём архив, явно указывая нужные файлы
    tar -czf "${ARCHIVE_NAME}" \
        lib/ \
        utils/ \
        modules/ \
        bsss-main.sh \
        local-runner.sh

    echo "[ ] Архив ${ARCHIVE_NAME} создан успешно"
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
