#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Проверяем параметр --uninstall (только для установленной версии)
if [[ "$1" == "--uninstall" ]]; then
    # Определяем директорию скрипта для проверки uninstall.sh
    readonly SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
    if [[ -f "${SCRIPT_DIR}/uninstall.sh" ]]; then
        exec "${SCRIPT_DIR}/uninstall.sh"
    else
        echo "Ошибка: скрипт удаления не найден" >&2
        exit 1
    fi
fi

# Определение директории, где находится скрипт (разрешаем символические ссылки)
readonly SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"

# Проверка наличия директории с модулями
if [[ ! -d "$MODULES_DIR" ]]; then
    echo "Ошибка: директория с модулями не найдена: $MODULES_DIR" >&2
    exit 1
fi

# Установка CACHE_BASE для указания на локальные модули
export CACHE_BASE="$MODULES_DIR"

# Запуск основного скрипта с передачей всех аргументов
exec "${SCRIPT_DIR}/bsss-main.sh" "$@"