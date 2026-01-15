#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh)

# @type:        Filter
# @description: Проверяет, был ли скрипт вызван через source
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - скрипт вызван через source
#               1 - скрипт запущен напрямую
is_sourced() {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

# По умолчанию включаем режим строгой обработки ошибок
set -Eeuo pipefail

# Проверка: если скрипт запущен через source, ОТКЛЮЧАЕМ строгий режим
if is_sourced; then
    # Отключаем строгий режим при source
    set +Eeuo pipefail
fi

readonly UTIL_NAME="bsss"
# shellcheck disable=SC2034
readonly SYMBOL_LINK_PATH="/usr/local/bin/$UTIL_NAME" # Used in lib/install_to_system_functions.sh
readonly ARCHIVE_URL="file:///tmp/project-v1.0.0.tar.gz"
# readonly ARCHIVE_URL="https://github.com/denor81/$UTIL_NAME/archive/refs/tags/v1.0.0.tar.gz"
readonly INSTALL_DIR="/opt/$UTIL_NAME"
readonly INSTALL_LOG_FILE_NAME=".uninstall_paths"
readonly LOCAL_RUNNER_FILE_NAME="local-runner.sh"
# shellcheck disable=SC2034
# shellcheck disable=SC2155
readonly CURRENT_MODULE_NAME="$(basename "$0")"
declare -a CLEANUP_COMMANDS=()
TMPARCHIVE=""

ONETIME_RUN_FLAG=0
SYS_INSTALL_FLAG=0
CLEANUP_DONE_FLAG=0

# Символы для обозначения статуса сообщений
# shellcheck disable=SC2034
readonly SYMBOL_SUCCESS="[V]"
readonly SYMBOL_QUESTION="[?]" # Используется в read (read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] Ваш выбор (Y/n/c): " -r)
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[X]"

# @type:        Sink
# @description: Выводит успешное сообщение с символом [V]
# @params:
#   message     Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_success() {
    echo "$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $1" >&2
}

# @type:        Sink
# @description: Выводит сообщение об ошибке с символом [X]
# @params:
#   message     Сообщение об ошибке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_error() {
    echo "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $1" >&2
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:
#   message     Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info() {
    echo "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $1" >&2
}

# @type:        Orchestrator
# @description: Очистка временных файлов
# @params:
#   reason      Причина очистки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
cleanup_handler() {
    if [ "$CLEANUP_DONE_FLAG" -eq 1 ]; then
        return 0 # Уже запускали, выходим
    fi
    local reason="$1"
    log_info "Запуск процедуры очистки по причине: $reason..."
    
    # Если команд нет, то очистка не требуется
    if [[ "${#CLEANUP_COMMANDS[@]}" -eq 0 ]]; then
        log_info "Очистка не требуется - ничего не было установлено/распаковано"
    fi

    # Проходим по всем командам в массиве
    for i in "${!CLEANUP_COMMANDS[@]}"; do
        local cmd="${CLEANUP_COMMANDS[$i]}"
        log_info "Удаляю: $cmd"
        # Используем eval для выполнения сохраненной строки команды
        eval "$cmd"
        # Удаляем выполненную команду из массива
        unset 'CLEANUP_COMMANDS[$i]'
    done
    log_success "Очистка завершена"
    CLEANUP_DONE_FLAG=1
}

# Передаем имя сигнала в функцию при вызове
trap 'cleanup_handler EXIT' EXIT
trap 'cleanup_handler ERR' ERR

# @type:        Sink
# @description: Выводит приветственное сообщение
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
hello() {
    log_info "Basic Server Security Setup (${UTIL_NAME^^}) - oneline запуск..."
}

# @type:        Filter
# @description: Проверяет права root
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - права root есть
#               1 - недостаточно прав
check_root_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
        return 1
    fi
}

# Спрашиваем пользователя о режиме запуска
ask_user_how_to_run() {
    log_info "Запустить ${UTIL_NAME^^} однократно?"
    log_info "Y - запуск однократно / n - установить / c - отмена"
    local choice

    while true; do
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] Ваш выбор (Y/n/c): " -r
        input=${REPLY:-Y}  # Если пустая строка, то Y по умолчанию
        
        # Проверка на допустимые символы (регистронезависимая для Y)
        if [[ ${input,,} =~ ^[ync]$ ]]; then
            choice=${input,,}
            break
        fi
        
        log_info "Неверный выбор [$input]. Пожалуйста, выберите [ync]"
    done

    if [[ $choice =~ ^[Cc]$ ]]; then
        log_info "Выбрана отмена ($choice)"
    elif [[ $choice =~ ^[Nn]$ ]]; then
        log_info "Выбрана установка ($choice)"
        # Проверяем, установлен ли уже скрипт
        if [[ -d "$INSTALL_DIR" ]]; then
            log_error "Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
            log_info "Для запуска Basic Server Security Setup (${UTIL_NAME^^}) используйте команду: sudo $UTIL_NAME, если не сработает - проверьте, что установлено в каталоге $INSTALL_DIR (ll $INSTALL_DIR) или куда ссылкается ссылка $UTIL_NAME (find /bin /usr/bin /usr/local/bin -type l -ls | grep $UTIL_NAME или realpath $UTIL_NAME)"
            log_info "Для удаления ранее установленного скрипта ${UTIL_NAME^^} выполните: sudo $UTIL_NAME -u"
            return 1
        fi
        SYS_INSTALL_FLAG=1
    elif [[ $choice =~ ^[Yy]$ ]]; then
        log_info "Выбран разовый запуск ($choice)"
        ONETIME_RUN_FLAG=1
    else
        log_error "Не корректное значение ($choice)"
        return 1
    fi
}

# @type:        Source
# @description: Создаёт временную директорию
# @params:
#   util_name   [optional] Имя утилиты для префикса (default: $UTIL_NAME)
#   add_to_cleanup [optional] Добавлять в CLEANUP_COMMANDS (default: true)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка создания
_create_tmp_dir() {
    local util_name="${1:-$UTIL_NAME}"  # Имя утилиты для префикса временной директории
    local add_to_cleanup="${2:-true}"  # Добавлять ли директорию в CLEANUP_COMMANDS
    
    local temp_dir
    temp_dir=$(mktemp -d --tmpdir "$util_name"-XXXXXX)
    
    # Устанавливаем глобальную переменную для обратной совместимости
    TEMP_PROJECT_DIR="$temp_dir"
    
    # Добавляем в CLEANUP_COMMANDS если нужно
    if [[ "$add_to_cleanup" == "true" ]]; then
        CLEANUP_COMMANDS+=("rm -rf $temp_dir")
    fi
    
    log_info "Создана временная директория $temp_dir"
}

# @type:        Source
# @description: Скачивает архив во временный файл
# @params:
#   archive_url [optional] URL архива (default: $ARCHIVE_URL)
#   tmparchive  [optional] Путь к временному файлу
#   add_to_cleanup [optional] Добавлять в CLEANUP_COMMANDS (default: true)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка загрузки
_download_archive() {
    local archive_url="${1:-$ARCHIVE_URL}"  # URL архива для скачивания
    local tmparchive="${2:-}"  # Путь к временному файлу архива (если не указан, будет создан)
    local add_to_cleanup="${3:-true}"  # Добавлять ли файл в CLEANUP_COMMANDS
    
    local curl_output=""
    
    # Если tmparchive не указан, создаем временный файл
    if [[ -z "$tmparchive" ]]; then
        tmparchive=$(mktemp --tmpdir "$UTIL_NAME"-archive-XXXXXX)
    fi
    
    log_info "Скачиваю архив: $archive_url"
    
    # Добавляем в CLEANUP_COMMANDS если нужно
    if [[ "$add_to_cleanup" == "true" ]]; then
        CLEANUP_COMMANDS+=("rm -f $tmparchive")
    fi
    
    curl_output=$(curl -fsSL "$archive_url" -o "$tmparchive" 2>&1) || {
        log_error "Ошибка загрузки архива - $curl_output"
        return 1
    }
    
    local fsize=""
    fsize=$(stat -c "%s" "$tmparchive" | awk '{printf "%.2f KB\n", $1/1024}')
    log_info "Архив скачан в $tmparchive (размер: $fsize, тип: $(file -ib "$tmparchive"))"
    
    # Устанавливаем глобальную переменную для обратной совместимости
    TMPARCHIVE="$tmparchive"
}

# @type:        Filter
# @description: Распаковывает архив
# @params:
#   tmparchive  [optional] Путь к архиву (default: $TMPARCHIVE)
#   temp_project_dir [optional] Директория для распаковки (default: $TEMP_PROJECT_DIR)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка распаковки
_unpack_archive() {
    local tmparchive="${1:-$TMPARCHIVE}"  # Берет параметр, либо дефолтную переменную
    local temp_project_dir="${2:-$TEMP_PROJECT_DIR}"  # Берет параметр, либо дефолтную переменную
    
    local tar_output=""
    tar_output=$(tar -xzf "$tmparchive" -C "$temp_project_dir" 2>&1 ) || {
        log_error "Ошибка распаковки архива - $tar_output"
        return 1
    }
    local dir_size=""
    dir_size=$(du -sb "$temp_project_dir" | cut -f1 | awk '{printf "%.2f KB\n", $1/1024}' )
    log_info "Архив распакован в $temp_project_dir (размер: $dir_size)"
}

# @type:        Filter
# @description: Проверяет успешность распаковки во временную директорию
# @params:
#   temp_project_dir [optional] Директория с проектом (default: $TEMP_PROJECT_DIR)
#   local_runner_file_name [optional] Имя файла (default: $LOCAL_RUNNER_FILE_NAME)
#   tmp_local_runner_path [optional] Путь к файлу (computed if not provided)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - файл найден
#               1 - файл не найден
_check_archive_unpacking() {
    local temp_project_dir="${1:-$TEMP_PROJECT_DIR}"  # Берет параметр, либо дефолтную переменную
    local local_runner_file_name="${2:-$LOCAL_RUNNER_FILE_NAME}"  # Берет параметр, либо дефолтную переменную
    
    TMP_LOCAL_RUNNER_PATH="${3:-$(find "$temp_project_dir" -type f -name "$local_runner_file_name")}"
    if [[ -z "$TMP_LOCAL_RUNNER_PATH" ]]; then
        log_error "При проверке наличия исполняемого файла произошла ошибка - файл $local_runner_file_name не найден - что то не так... либо ошибка при рапаковке архива, либо ошибка в путях."
        return 1
    fi
    log_info "Исполняемый файл $local_runner_file_name найден"
}

# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ УСТАНОВКИ

# @type:        Sink
# @description: Добавляет путь в файл лога установки для последующего удаления
# @params:
#   uninstall_path Путь для добавления в лог удаления
#   install_log_path [optional] Путь к файлу лога (default: $INSTALL_DIR/$INSTALL_LOG_FILE_NAME)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - путь не указан
_add_uninstall_path() {
    local uninstall_path="${1:-}"  # Путь для добавления в лог удаления
    local install_log_path="${2:-$INSTALL_DIR/$INSTALL_LOG_FILE_NAME}"  # Путь к файлу лога удаления

    # Проверяем, что передан путь для добавления
    if [[ -z "$uninstall_path" ]]; then
        log_error "Не указан путь для добавления в лог удаления"
        return 1
    fi

    # Добавляем путь в файл лога, если его там еще нет
    if ! grep -Fxq "$uninstall_path" "$install_log_path" 2>/dev/null; then
        echo "$uninstall_path" >> "$install_log_path"
        log_info "Путь $uninstall_path добавлен в лог удаления $install_log_path"
    fi
}

# @type:        Filter
# @description: Проверяет наличие символической ссылки
# @params:
#   symlink_path [optional] Путь к ссылке (default: $SYMBOL_LINK_PATH)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - ссылка не существует
#               1 - ссылка уже существует
_check_symlink_exists() {
    local symlink_path="${1:-$SYMBOL_LINK_PATH}"  # Берет параметр, либо дефолтную переменную
    
    if [[ -L "$symlink_path" ]]; then
        log_error "Символическая ссылка $UTIL_NAME уже существует"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Создание директории установки
# @params:
#   install_dir [optional] Директория установки (default: $INSTALL_DIR)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка создания
_create_install_directory() {
    local install_dir="${1:-$INSTALL_DIR}"  # Берет параметр, либо дефолтную переменную
    
    log_info "Создаю директорию $install_dir"
    mkdir -p "$install_dir" || {
        log_error "Не удалось создать директорию $install_dir"
        return 1
    }
    _add_uninstall_path "$install_dir"
}

# @type:        Orchestrator
# @description: Копирование файлов установки
# @params:
#   tmp_dir_path [optional] Временная директория (computed from TMP_LOCAL_RUNNER_PATH if not provided)
#   install_dir [optional] Директория установки (default: $INSTALL_DIR)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка копирования
_copy_installation_files() {
    local tmp_dir_path="${1:-$(dirname "$TMP_LOCAL_RUNNER_PATH")}"  # Берет параметр, либо вычисляет из TMP_LOCAL_RUNNER_PATH
    local install_dir="${2:-$INSTALL_DIR}"  # Берет параметр, либо дефолтную переменную
    
    log_info "Копирую файлы из $tmp_dir_path в $install_dir"
    
    cp -r "$tmp_dir_path"/* "$install_dir/" || {
        log_error "Не удалось скопировать файлы"
        return 1
    }
}

# @type:        Orchestrator
# @description: Создание символической ссылки
# @params:
#   install_dir [optional] Директория установки (default: $INSTALL_DIR)
#   local_runner_file_name [optional] Имя файла (default: $LOCAL_RUNNER_FILE_NAME)
#   symbol_link_path [optional] Путь к ссылке (default: $SYMBOL_LINK_PATH)
#   util_name [optional] Имя утилиты (default: $UTIL_NAME)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка создания ссылки
_create_symlink() {
    local install_dir="${1:-$INSTALL_DIR}"  # Берет параметр, либо дефолтную переменную
    local local_runner_file_name="${2:-$LOCAL_RUNNER_FILE_NAME}"  # Берет параметр, либо дефолтную переменную
    local symbol_link_path="${3:-$SYMBOL_LINK_PATH}"  # Берет параметр, либо дефолтную переменную
    local util_name="${4:-$UTIL_NAME}"  # Берет параметр, либо дефолтную переменную
    
    local local_runner_path="$install_dir/$local_runner_file_name"
    
    ln -s "$local_runner_path" "$symbol_link_path" || {
        log_error "Не удалось создать символическую ссылку"
        return 1
    }
    
    log_info "Создана символическая ссылка $util_name для запуска $local_runner_path. (Расположение ссылки: $(dirname "$symbol_link_path"))"
    _add_uninstall_path "$symbol_link_path"
}

# @type:        Orchestrator
# @description: Установка прав на выполнение
# @params:
#   install_dir [optional] Директория установки (default: $INSTALL_DIR)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
_set_execution_permissions() {
    local install_dir="${1:-$INSTALL_DIR}"  # Берет параметр, либо дефолтную переменную
    
    log_info "Устанавливаю права запуска (+x) в $install_dir для .sh файлов"
    chmod +x "$install_dir"/*.sh 2>/dev/null
    # Возвращаем 0 даже если нет .sh файлов - это нормально
}

# @type:        Orchestrator
# @description: Функция установки в систему
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка установки
install_to_system() {
    log_info "Устанавливаю ${UTIL_NAME^^} в систему..."
    
    # Порядок важен - проверяем условия перед действиями
    _check_symlink_exists
    _create_install_directory
    _copy_installation_files
    _create_symlink
    _set_execution_permissions
    
    log_success "Установка в систему завершена"
    log_info "Используйте для запуска: sudo $UTIL_NAME, для удаления: sudo $UTIL_NAME -u"
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка выполнения
main() {
    hello
    check_root_permissions
    ask_user_how_to_run
    if [[ "$ONETIME_RUN_FLAG" -eq 1 || "$SYS_INSTALL_FLAG" -eq 1 ]]; then
        _create_tmp_dir
        _download_archive
        _unpack_archive "$TMPARCHIVE" "$TEMP_PROJECT_DIR"
        _check_archive_unpacking "$TEMP_PROJECT_DIR" "$LOCAL_RUNNER_FILE_NAME"
    fi
    if [[ "$ONETIME_RUN_FLAG" -eq 1 ]]; then
        bash "$TMP_LOCAL_RUNNER_PATH"
    fi
    if [[ "$SYS_INSTALL_FLAG" -eq 1 ]]; then
        install_to_system
    fi
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi