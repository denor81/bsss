#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh | sudo bash

set -Eeuo pipefail

readonly UTIL_NAME="bsss"
readonly REPO_URL="https://github.com"
readonly ARCHIVE_FILE_NAME="bsss-framework-latest.tar.gz"
readonly ARCHIVE_URL="${REPO_URL}/denor81/${UTIL_NAME}/releases/latest/download/${ARCHIVE_FILE_NAME}"

readonly SYMBOL_LINK_PATH="/usr/local/bin/$UTIL_NAME"
readonly INSTALL_DIR="/opt/$UTIL_NAME"
readonly INSTALL_LOG_FILE_NAME=".uninstall_paths"
readonly MAIN_SCRIPT_FILE_NAME="main.sh"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

declare -a CLEANUP_COMMANDS=()
TMPARCHIVE=""
ONETIME_RUN_FLAG=0
SYS_INSTALL_FLAG=0
CLEANUP_DONE_FLAG=0

readonly SYMBOL_SUCCESS="[v]"
readonly SYMBOL_QUESTION="[?]"
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[x]"

# Journal mapping: BSSS log type -> systemd journal priority
readonly -A JOURNAL_MAP=(
    [SUCCESS]="notice"
    [INFO]="info"
    [ERROR]="err"
)

# Check if logger command is available for journal logging
command -v logger >/dev/null 2>&1 && readonly LOG_JOURNAL_ENABLED=1 || readonly LOG_JOURNAL_ENABLED=0

# @type:        Sink
# @description: Sends message to systemd journal if logging is enabled
# @params:      message - Message to log
#               log_type - BSSS log type (SUCCESS, ERROR, INFO)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log::to_journal() {
    local msg="$1"
    local log_type="$2"
    local priority

    if (( LOG_JOURNAL_ENABLED )); then
        priority="${JOURNAL_MAP[$log_type]:-info}"
        logger --id -t "$UTIL_NAME" -p "user.$priority" "[$CURRENT_MODULE_NAME] $msg" || true
    fi
}

# @type:        Sink
# @description: Выводит успешное сообщение с символом [v]
# @params:      message - Сообщение для вывода
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_success() {
    echo -e "$SYMBOL_SUCCESS [$CURRENT_MODULE_NAME] $1" >&2 || true
    log::to_journal "$1" "SUCCESS"
}

# @type:        Sink
# @description: Выводит сообщение об ошибке с символом [x]
# @params:      message - Сообщение об ошибке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_error() {
    echo -e "$SYMBOL_ERROR [$CURRENT_MODULE_NAME] $1" >&2 || true
    log::to_journal "$1" "ERROR"
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info() {
    echo -e "$SYMBOL_INFO [$CURRENT_MODULE_NAME] $1" >&2 || true
    log::to_journal "$1" "INFO"
}

# @type:        Sink
# @description: Выводит приветственное сообщение
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
install::ui::hello() {
    log_info "Basic Server Security Setup (${UTIL_NAME^^}) - oneline запуск..."
}

# @type:        Orchestrator
# @description: Очистка временных файлов
# @params:
#   reason      Причина очистки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
install::cleanup::handler() {
    if [ "$CLEANUP_DONE_FLAG" -eq 1 ]; then
        return 0
    fi
    local reason="$1"
    log_info "Запуск процедуры очистки по причине: $reason..."
    
    if [[ "${#CLEANUP_COMMANDS[@]}" -eq 0 ]]; then
        log_info "Очистка не требуется - ничего не было установлено/распаковано"
    fi

    local i
    for i in "${!CLEANUP_COMMANDS[@]}"; do
        local cmd="${CLEANUP_COMMANDS[$i]}"
        log_info "Удаляю: $cmd"
        rm -rf $cmd
        unset 'CLEANUP_COMMANDS[$i]'
    done
    log_success "Очистка завершена"
    CLEANUP_DONE_FLAG=1
}

trap 'install::cleanup::handler EXIT' EXIT
trap 'install::cleanup::handler ERR' ERR

# @type:        Filter
# @description: Проверяет права root
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - права root есть
#               1 - недостаточно прав
install::permissions::check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
        return 1
    fi
}

# @type:        Interactive
# @description: Запрашивает у пользователя режим запуска (однократно/установка/отмена)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - режим выбран (ONETIME_RUN_FLAG или SYS_INSTALL_FLAG установлен)
#               1 - отмена или ошибка выбора
#               2 - отменено пользователем
install::ui::ask_run_mode() {
    log_info "Запустить ${UTIL_NAME^^} однократно?"
    log_info "Y - запуск однократно / n - установить / c - отмена"
    local choice

    while true; do
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] Ваш выбор (Y/n/c): " -r </dev/tty
        choice=${REPLY:-Y}
        
        if [[ ${choice,,} =~ ^[ync]$ ]]; then
            break
        fi
        
        log_info "Неверный выбор [$choice]. Пожалуйста, выберите [ync]"
    done

    if [[ $choice =~ ^[Cc]$ ]]; then
        log_info "Выбрана отмена ($choice)"
        return 2
    elif [[ $choice =~ ^[Nn]$ ]]; then
        log_info "Выбрана установка ($choice)"
        if [[ -d "$INSTALL_DIR" ]]; then
            log_error "Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
            log_info "Для запуска Basic Server Security Setup (${UTIL_NAME^^}) используйте команду: sudo $UTIL_NAME, если не сработает - проверьте, что установлено в каталоге $INSTALL_DIR (ll $INSTALL_DIR) или куда ссылается ссылка $UTIL_NAME (find /bin /usr/bin /usr/local/bin -type l -ls | grep $UTIL_NAME или realpath $UTIL_NAME)"
            log_info "Для удаления ранее установленного скрипта ${UTIL_NAME^^} выполните: sudo $UTIL_NAME -u"
            return 1
        fi
        SYS_INSTALL_FLAG=1
    elif [[ $choice =~ ^[Yy]$ ]]; then
        log_info "Выбран разовый запуск ($choice)"
        ONETIME_RUN_FLAG=1
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
install::tmp::create() {
    local util_name="${1:-$UTIL_NAME}"
    local add_to_cleanup="${2:-true}"
    
    local temp_dir
    temp_dir=$(mktemp -d --tmpdir "$util_name"-XXXXXX)
    
    TEMP_PROJECT_DIR="$temp_dir"
    
    if [[ "$add_to_cleanup" == "true" ]]; then
        CLEANUP_COMMANDS+=("$temp_dir")
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
install::download::archive() {
    local archive_url="${1:-$ARCHIVE_URL}"
    local tmparchive="${2:-}"
    local add_to_cleanup="${3:-true}"
    
    if [[ -z "$tmparchive" ]]; then
        tmparchive=$(mktemp --tmpdir "$UTIL_NAME"-archive-XXXXXX.tar.gz)
    fi
    
    log_info "Скачиваю архив: $archive_url"
    
    if [[ "$add_to_cleanup" == "true" ]]; then
        CLEANUP_COMMANDS+=("$tmparchive")
    fi

    if ! curl -fL --progress-meter "$archive_url" -o "$tmparchive"; then
        log_error "Не удалось скачать архив (проверьте интернет или URL)"
        return 1
    fi
    
    local fsize=""
    fsize=$(stat -c "%s" "$tmparchive" | gawk '{printf "%.2f KB\n", $1/1024}')
    log_info "Архив скачан в $tmparchive (размер: $fsize, тип: $(file -ib "$tmparchive"))"
    
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
install::archive::unpack() {
    local tmparchive="${1:-$TMPARCHIVE}"
    local temp_project_dir="${2:-$TEMP_PROJECT_DIR}"
    
    local tar_output=""
    tar_output=$(tar -xzf "$tmparchive" -C "$temp_project_dir" 2>&1 ) || {
        log_error "Ошибка распаковки архива - $tar_output"
        return 1
    }
    local dir_size=""
    dir_size=$(du -sb "$temp_project_dir" | cut -f1 | gawk '{printf "%.2f KB\n", $1/1024}' )
    log_info "Архив распакован в $temp_project_dir (размер: $dir_size)"
}

# @type:        Filter
# @description: Проверяет успешность распаковки во временную директорию
# @params:
#   temp_project_dir [optional] Директория с проектом (default: $TEMP_PROJECT_DIR)
#   main_script_file_name [optional] Имя файла (default: $MAIN_SCRIPT_FILE_NAME)
#   tmp_main_script_path [optional] Путь к файлу (computed if not provided)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - файл найден
#               1 - файл не найден
install::archive::check() {
    local temp_project_dir="${1:-$TEMP_PROJECT_DIR}"
    local main_script_file_name="${2:-$MAIN_SCRIPT_FILE_NAME}"

    TMP_MAIN_SCRIPT_PATH="${3:-$(find "$temp_project_dir" -type f -name "$main_script_file_name")}"
    if [[ -z "$TMP_MAIN_SCRIPT_PATH" ]]; then
        log_error "При проверке наличия исполняемого файла произошла ошибка - файл $main_script_file_name не найден - что то не так... либо ошибка при рапаковке архива, либо ошибка в путях."
        return 1
    fi
    log_info "Исполняемый файл $main_script_file_name найден"
}

# @type:        Sink
# @description: Добавляет путь в файл лога установки для последующего удаления
# @params:
#   uninstall_path Путь для добавления в лог удаления
#   install_log_path [optional] Путь к файлу лога (default: $INSTALL_DIR/$INSTALL_LOG_FILE_NAME)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - путь не указан
install::log::add_path() {
    local uninstall_path="${1:-}"
    local install_log_path="${2:-$INSTALL_DIR/$INSTALL_LOG_FILE_NAME}"

    if [[ -z "$uninstall_path" ]]; then
        log_error "Не указан путь для добавления в лог удаления"
        return 1
    fi

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
install::symlink::check_exists() {
    local symlink_path="${1:-$SYMBOL_LINK_PATH}"
    
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
install::dir::create() {
    local install_dir="${1:-$INSTALL_DIR}"
    
    log_info "Создаю директорию $install_dir"
    mkdir -p "$install_dir" || {
        log_error "Не удалось создать директорию $install_dir"
        return 1
    }
    install::log::add_path "$install_dir"
}

# @type:        Orchestrator
# @description: Копирование файлов установки
# @params:
#   tmp_dir_path [optional] Временная директория (computed from TMP_MAIN_SCRIPT_PATH if not provided)
#   install_dir [optional] Директория установки (default: $INSTALL_DIR)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка копирования
install::files::copy() {
    local tmp_dir_path="${1:-$(dirname "$TMP_MAIN_SCRIPT_PATH")}"
    local install_dir="${2:-$INSTALL_DIR}"
    
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
#   main_script_file_name [optional] Имя файла (default: $MAIN_SCRIPT_FILE_NAME)
#   symbol_link_path [optional] Путь к ссылке (default: $SYMBOL_LINK_PATH)
#   util_name [optional] Имя утилиты (default: $UTIL_NAME)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка создания ссылки
install::symlink::create() {
    local install_dir="${1:-$INSTALL_DIR}"
    local main_script_file_name="${2:-$MAIN_SCRIPT_FILE_NAME}"
    local symbol_link_path="${3:-$SYMBOL_LINK_PATH}"
    local util_name="${4:-$UTIL_NAME}"

    local main_script_path="$install_dir/$main_script_file_name"

    ln -s "$main_script_path" "$symbol_link_path" || {
        log_error "Не удалось создать символическую ссылку"
        return 1
    }

    log_info "Создана символическая ссылка $util_name для запуска $main_script_path. (Расположение ссылки: $(dirname "$symbol_link_path"))"
    install::log::add_path "$symbol_link_path"
}

# @type:        Orchestrator
# @description: Установка прав на выполнение
# @params:
#   install_dir [optional] Директория установки (default: $INSTALL_DIR)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
install::permissions::set() {
    local install_dir="${1:-$INSTALL_DIR}"
    
    log_info "Устанавливаю права запуска (+x) в $install_dir для .sh файлов"
    chmod +x "$install_dir"/*.sh 2>/dev/null
}

# @type:        Orchestrator
# @description: Функция установки в систему
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка установки
install::to_system() {
    log_info "Устанавливаю ${UTIL_NAME^^} в систему..."
    
    install::symlink::check_exists
    install::dir::create
    install::files::copy
    install::symlink::create
    install::permissions::set
    
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
install::runner::main() {
    install::ui::hello
    install::permissions::check_root
    install::ui::ask_run_mode
    if [[ "$ONETIME_RUN_FLAG" -eq 1 || "$SYS_INSTALL_FLAG" -eq 1 ]]; then
        install::tmp::create
        install::download::archive
        install::archive::unpack "$TMPARCHIVE" "$TEMP_PROJECT_DIR"
        install::archive::check "$TEMP_PROJECT_DIR" "$MAIN_SCRIPT_FILE_NAME"
    fi
    if [[ "$ONETIME_RUN_FLAG" -eq 1 ]]; then
        bash "$TMP_MAIN_SCRIPT_PATH"
    fi
    if [[ "$SYS_INSTALL_FLAG" -eq 1 ]]; then
        install::to_system
    fi
}

install::runner::main
