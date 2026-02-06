#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh | sudo bash

#
#
#
# Логирование oneline-runner.sh происходит в journalctl
# journalctl -t bsss --since '10 minutes ago'
#
#
#

set -Eeuo pipefail

readonly UTIL_NAME="bsss"
readonly REPO_URL="https://github.com"
readonly ARCHIVE_FILE_NAME="bsss-framework-latest.tar.gz"
# readonly ARCHIVE_URL="${REPO_URL}/denor81/${UTIL_NAME}/releases/latest/download/${ARCHIVE_FILE_NAME}"
readonly ARCHIVE_URL="file:///home/ubuntu/bsss/project-v1.0.0.tar.gz"

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
INSTALLER_LANG=""

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

trap 'install::cleanup::handler' EXIT

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
# @description: ТОЛЬКО в файл - вопрос с символом [?]
#               В терминал вопрос выводится стандартными средствами read
# @params:      question - вопрос
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_question() {
    local msg="$1"
    local type="QUESTION"
    log::to_journal "$msg" "$type"
}

# @type:        Sink
# @description: ТОЛЬКО в файл - ответ с символом [?]
#               В терминал ответ выводится стандартными средствами read
# @params:      answer
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_answer() {
    local msg="$1"
    local type="ANSWER"
    log::to_journal "$msg" "$type"
}

# @type:        Source
# @description: Переводчик сообщений по ключу для oneline-runner
# @params:      message_key - Ключ сообщения
#               args - Аргументы для форматирования (опционально)
# @stdin:       нет
# @stdout:      Переведенное сообщение
# @exit_code:   0 - успех
_() {
    local key="$1"
    shift
    local value=""

    if [[ "$INSTALLER_LANG" == "en" ]]; then
        value="${I18N_MESSAGES_EN[$key]:-$key}"
    else
        value="${I18N_MESSAGES_RU[$key]:-$key}"
    fi

    if [[ $# -gt 0 ]]; then
        printf "$value" "$@"
    else
        printf '%s' "$value"
    fi
}

# @type:        Interactive
# @description: Запрашивает у пользователя значение
# @params:      question - Вопрос
#               default - Значение по умолчанию
#               pattern - Regex паттерн ожидаемого ввода
#               hint - Подсказка какие значения ожидаются
# @stdin:       Ожидает ввод пользователя (TTY)
# @stdout:      Полученное значение
# @exit_code:   0 - успешно
installer::ask_value() {
    local question="$1" default="$2" pattern="$3" hint="$4" cancel_keyword="${5:-}"
    local choice

    while true; do
        # log_question "$question [$hint]"
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] $question [$hint]: " -r choice </dev/tty
        choice=${choice:-$default}
        log_answer "$choice"

        # Возвращаем код 2 при отмене
        [[ -n "$cancel_keyword" && "$choice" == "$cancel_keyword" ]] && return 2

        if [[ "$choice" =~ ^$pattern$ ]]; then
            printf '%s\0' "$choice"
            break
        fi
        log_error "$(_ "common.error_invalid_input" "[$hint]")"
    done
}

# @type:        Sink
# @description: Запрашивает у пользователя язык установки
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - язык выбран
installer::ui::ask_language() {
    local lang

    lang=$(installer::ask_value "$(_ "installer.no_translate" "Русский [r] | English [e]")" "r" "[re]" "r/e")

    if [[ "$lang" =~ ^[Ee]$ ]]; then
        INSTALLER_LANG="en"
    else
        INSTALLER_LANG="ru"
    fi

    log_info "$(_ "installer.ask_language.selected") [$INSTALLER_LANG]"
}

# @type:        Sink
# @description: Выводит приветственное сообщение
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
install::ui::hello() {
    log_info "$(_ "installer.hello" "${UTIL_NAME^^}")"
}

# @type:        Orchestrator
# @description: Очистка временных файлов
# @params:
#   reason      Причина очистки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
install::cleanup::handler() {
    local rc="$?"

    if [ "$CLEANUP_DONE_FLAG" -eq 1 ]; then
        return 0
    fi

    log_info "$(_ "installer.cleanup.start" "[RC: $rc]")"

    if [[ "${#CLEANUP_COMMANDS[@]}" -eq 0 ]]; then
        log_info "$(_ "installer.cleanup.nothing_to_cleanup")"
    fi

    local i
    for i in "${!CLEANUP_COMMANDS[@]}"; do
        local cmd="${CLEANUP_COMMANDS[$i]}"
        log_info "$(_ "installer.cleanup.removing" "$cmd")"
        rm -rf $cmd
        unset 'CLEANUP_COMMANDS[$i]'
    done
    log_success "$(_ "installer.cleanup.complete")"
    CLEANUP_DONE_FLAG=1
}

# @type:        Filter
# @description: Проверяет права root
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - права root есть
#               1 - недостаточно прав
install::permissions::check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "$(_ "installer.error_root_required")"
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
    local choice

    choice=$(installer::ask_value "$(_ "installer.ask_run_mode.prompt")" "y" "[yic]" "Y/i/c" "c")

    if [[ $choice =~ ^[Cc]$ ]]; then
        log_info "$(_ "installer.ask_run_mode.cancelled" "$choice")"
        return 2
    elif [[ $choice =~ ^[Ii]$ ]]; then
        log_info "$(_ "installer.ask_run_mode.install" "$choice")"
        if [[ -d "$INSTALL_DIR" ]]; then
            log_error "$(_ "installer.error_already_installed")"
            log_info "$(_ "installer.info_installed_usage")"
            log_info "$(_ "installer.info_installed_uninstall")"
            return 1
        fi
        SYS_INSTALL_FLAG=1
    elif [[ $choice =~ ^[Yy]$ ]]; then
        log_info "$(_ "installer.ask_run_mode.onetime" "$choice")"
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

    log_info "$(_ "installer.tmpdir.created" "$temp_dir")"
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

    log_info "$(_ "installer.download.start" "$archive_url")"

    if [[ "$add_to_cleanup" == "true" ]]; then
        CLEANUP_COMMANDS+=("$tmparchive")
    fi

    if ! curl -fL --progress-meter "$archive_url" -o "$tmparchive"; then
        log_error "$(_ "installer.download.failed")"
        return 1
    fi

    local fsize=""
    fsize=$(stat -c "%s" "$tmparchive" | gawk '{printf "%.2f KB\n", $1/1024}')
    log_info "$(_ "installer.downloaded" "$tmparchive" "$fsize" "$(file -ib "$tmparchive")")"

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
        log_error "$(_ "installer.unpack.failed" "$tar_output")"
        return 1
    }
    local dir_size=""
    dir_size=$(du -sb "$temp_project_dir" | cut -f1 | gawk '{printf "%.2f KB\n", $1/1024}' )
    log_info "$(_ "installer.unpacked" "$temp_project_dir" "$dir_size")"
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
        log_error "$(_ "installer.check.not_found" "$main_script_file_name")"
        return 1
    fi
    log_info "$(_ "installer.check.found" "$main_script_file_name")"
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
        log_error "$(_ "installer.log.no_path")"
        return 1
    fi

    if ! grep -Fxq "$uninstall_path" "$install_log_path" 2>/dev/null; then
        echo "$uninstall_path" >> "$install_log_path"
        log_info "$(_ "installer.log.path_added" "$uninstall_path" "$install_log_path")"
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
        log_error "$(_ "installer.symlink.exists" "$UTIL_NAME")"
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

    log_info "$(_ "installer.dir.creating" "$install_dir")"
    mkdir -p "$install_dir" || {
        log_error "$(_ "installer.dir.create_failed" "$install_dir")"
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

    log_info "$(_ "installer.files.copying" "$tmp_dir_path" "$install_dir")"

    cp -r "$tmp_dir_path"/* "$install_dir/" || {
        log_error "$(_ "installer.files.copy_failed")"
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
        log_error "$(_ "installer.symlink.create_failed")"
        return 1
    }

    log_info "$(_ "installer.symlink.created" "$util_name" "$main_script_path" "$(dirname "$symbol_link_path")")"
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

    log_info "$(_ "installer.permissions.setting" "$install_dir")"
    # chmod +x "$install_dir"/*.sh 2>/dev/null
    chmod a+rwx,o+t "$install_dir" 2>/dev/null

}

# @type:        Orchestrator
# @description: Функция установки в систему
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка установки
install::to_system() {
    install::symlink::check_exists
    install::dir::create
    install::files::copy
    install::symlink::create
    install::permissions::set

    log_success "$(_ "installer.install.complete")"
    log_info "$(_ "installer.install.usage" "$UTIL_NAME" "$UTIL_NAME")"
}

sys::run_or_install::prepare() {
    install::tmp::create
    install::download::archive
    install::archive::unpack "$TMPARCHIVE" "$TEMP_PROJECT_DIR"
    install::archive::check "$TEMP_PROJECT_DIR" "$MAIN_SCRIPT_FILE_NAME"
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка выполнения
install::runner::main() {
    log_info "$(_ "installer.no_translate" "For logs type [journalctl -t bsss --since '10 minutes ago']")"
    installer::ui::ask_language
    install::ui::hello
    install::permissions::check_root
    install::ui::ask_run_mode

    if [[ "$ONETIME_RUN_FLAG" -eq 1 ]]; then
        sys::run_or_install::prepare
        bash "$TMP_MAIN_SCRIPT_PATH"
    fi
    if [[ "$SYS_INSTALL_FLAG" -eq 1 ]]; then
        log_info "Будет скачан архив последней версии релиза ${UTIL_NAME^^} [$ARCHIVE_URL]"
        log_info "Будет произведена установка ${UTIL_NAME^^} в директорию [$INSTALL_DIR]"
        log_info "Запускать sudo $UTIL_NAME"
        installer::ask_value "Продолжить?" "y" "[yn]" "Y/n" "n"

        sys::run_or_install::prepare
        install::to_system
    fi
}

# Russian translations
declare -gA I18N_MESSAGES_RU=(
    [installer.no_translate]="%s"
    [installer.hello]="Basic Server Security Setup (%s) - oneline запуск..."
    [installer.ask_language.selected]="Выбран язык"
    [installer.error_invalid_input]="Неверный выбор"
    [installer.cleanup.start]="Запуск процедуры очистки: %s"
    [installer.cleanup.nothing_to_cleanup]="Очистка не требуется - ничего не было установлено/распаковано"
    [installer.cleanup.removing]="Удаляю: %s"
    [installer.cleanup.complete]="Очистка завершена"
    [installer.error_root_required]="Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
    [installer.ask_run_mode.prompt]="Разовый запуск [Y] | Установка [i] | Отмена [c]"
    [installer.ask_run_mode.invalid]="Неверный выбор [%s]. Пожалуйста, выберите [yic]"
    [installer.ask_run_mode.cancelled]="Выбрана отмена (%s)"
    [installer.ask_run_mode.install]="Выбрана установка (%s)"
    [installer.ask_run_mode.onetime]="Выбран разовый запуск (%s)"
    [installer.error_already_installed]="Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
    [installer.info_installed_usage]="Для запуска Basic Server Security Setup (${UTIL_NAME^^}) используйте команду: sudo ${UTIL_NAME}, если не сработает - проверьте, что установлено в каталоге ${INSTALL_DIR} или куда ссылается ссылка ${UTIL_NAME} [find /bin /usr/bin /usr/local/bin -type l -ls | grep ${UTIL_NAME}] или [realpath ${UTIL_NAME}]"
    [installer.info_installed_uninstall]="Для удаления ранее установленного скрипта ${UTIL_NAME^^} выполните: sudo ${UTIL_NAME} -u"
    [installer.tmpdir.created]="Создана временная директория %s"
    [installer.download.start]="Скачиваю архив: %s"
    [installer.download.failed]="Не удалось скачать архив (проверьте интернет или URL)"
    [installer.downloaded]="Архив скачан в %s (размер: %s, тип: %s)"
    [installer.unpack.failed]="Ошибка распаковки архива - %s"
    [installer.unpacked]="Архив распакован в %s (размер: %s)"
    [installer.check.not_found]="При проверке наличия исполняемого файла произошла ошибка - файл %s не найден - что то не так... либо ошибка при рапаковке архива, либо ошибка в путях."
    [installer.check.found]="Исполняемый файл %s найден"
    [installer.log.no_path]="Не указан путь для добавления в лог удаления"
    [installer.log.path_added]="Путь %s добавлен в лог удаления %s"
    [installer.symlink.exists]="Символическая ссылка %s уже существует"
    [installer.dir.creating]="Создаю директорию %s"
    [installer.dir.create_failed]="Не удалось создать директорию %s"
    [installer.files.copying]="Копирую файлы из %s в %s"
    [installer.files.copy_failed]="Не удалось скопировать файлы"
    [installer.symlink.create_failed]="Не удалось создать символическую ссылку"
    [installer.symlink.created]="Создана символическая ссылка %s для запуска %s. (Расположение ссылки: %s)"
    [installer.permissions.setting]="Устанавливаю права запуска (+x) в %s для .sh файлов"
    [installer.install.start]="Устанавливаю %s в систему..."
    [installer.install.complete]="Установка в систему завершена"
    [installer.install.usage]="Используйте для запуска: sudo %s, для удаления: sudo %s -u"
)

# English translations
declare -gA I18N_MESSAGES_EN=(
    [installer.no_translate]="%s"
    [installer.hello]="Basic Server Security Setup (%s) - oneline execution..."
    [installer.ask_language.selected]="Language selected"
    [installer.error_invalid_input]="Invalid choice"
    [installer.cleanup.start]="Starting cleanup procedure: %s"
    [installer.cleanup.nothing_to_cleanup]="Cleanup not required - nothing was installed/unpacked"
    [installer.cleanup.removing]="Removing: %s"
    [installer.cleanup.complete]="Cleanup completed"
    [installer.error_root_required]="Root privileges required or run via 'sudo'. Running as regular user."
    [installer.ask_run_mode.prompt]="One-time run [Y] | Install [i] | Cancel [c]"
    [installer.ask_run_mode.invalid]="Invalid choice [%s]. Please choose [yic]"
    [installer.ask_run_mode.cancelled]="Cancel selected (%s)"
    [installer.ask_run_mode.install]="Install selected (%s)"
    [installer.ask_run_mode.onetime]="One-time run selected (%s)"
    [installer.error_already_installed]="Script already installed in the system or another script with the same directory name is installed."
    [installer.info_installed_usage]="To launch Basic Server Security Setup (${UTIL_NAME^^}), use the command: sudo ${UTIL_NAME}. If it doesn't work, verify the installation directory is ${INSTALL_DIR} or check where the symlink points: ${UTIL_NAME} [find /bin /usr/bin /usr/local/bin -type l -ls | grep ${UTIL_NAME}] or [realpath ${UTIL_NAME}]"
    [installer.info_installed_uninstall]="To uninstall previously installed script ${UTIL_NAME^^} run: sudo ${UTIL_NAME} -u"
    [installer.tmpdir.created]="Created temporary directory %s"
    [installer.download.start]="Downloading archive: %s"
    [installer.download.failed]="Failed to download archive (check internet or URL)"
    [installer.downloaded]="Archive downloaded to %s (size: %s, type: %s)"
    [installer.unpack.failed]="Archive unpack error - %s"
    [installer.unpacked]="Archive unpacked to %s (size: %s)"
    [installer.check.not_found]="Error checking executable file - file %s not found - something is wrong... either archive unpack error or path error."
    [installer.check.found]="Executable file %s found"
    [installer.log.no_path]="Path not specified for uninstall log"
    [installer.log.path_added]="Path %s added to uninstall log %s"
    [installer.symlink.exists]="Symbolic link %s already exists"
    [installer.dir.creating]="Creating directory %s"
    [installer.dir.create_failed]="Failed to create directory %s"
    [installer.files.copying]="Copying files from %s to %s"
    [installer.files.copy_failed]="Failed to copy files"
    [installer.symlink.create_failed]="Failed to create symbolic link"
    [installer.symlink.created]="Created symbolic link %s for running %s. (Link location: %s)"
    [installer.permissions.setting]="Setting execute permissions (+x) in %s for .sh files"
    [installer.install.start]="Installing %s to system..."
    [installer.install.complete]="System installation completed"
    [installer.install.usage]="Use to run: sudo %s, to uninstall: sudo %s -u"
)

install::runner::main
