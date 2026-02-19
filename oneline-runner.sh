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
readonly ARCHIVE_URL="${REPO_URL}/denor81/${UTIL_NAME}/releases/latest/download/${ARCHIVE_FILE_NAME}"
readonly SIGNATURE_FILE_NAME="bsss-framework-latest.tar.gz.asc"
readonly SIGNATURE_URL="${REPO_URL}/denor81/${UTIL_NAME}/releases/latest/download/${SIGNATURE_FILE_NAME}"

readonly SYMBOL_LINK_PATH="/usr/local/bin/$UTIL_NAME"
readonly INSTALL_DIR="/opt/$UTIL_NAME"
readonly INSTALL_LOG_FILE_NAME=".uninstall_paths"
readonly MAIN_SCRIPT_FILE_NAME="main.sh"
readonly CURRENT_MODULE_NAME="$(basename "$0")"
readonly LANG_FILE="${INSTALL_DIR}/.lang"

readonly GPG_PUBLIC_KEY_ASCII='-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBGmV2ksBEACzS8iCRQwuvl4xtNPl0fVJ0far5DISc/24vHBADsEC8eNVV+4Q
FKvn79qbfSamlEuJE0gYdZgVK3RAxjvLUEnLdHbDxEC8GWhQKIbPwIDywORVRCRi
oFJqZjwzbeVqvq1CUAutYAWOyEtuLsT5KPkjsAl4kmUEV5TruiBz1wPvxnXUfRii
D0g7W2HeManGkqnfAMfOvZMZcqVZ5WksuDiFKXwPQ/vIY0Dti/6EYbrJqdA3JmDx
75cvgG7x7Vjz8E9BgAXNS4X1mMA2/p4gOQwgCMgEubwWlJQ4R+s6eCwi7nCBfH9O
bzuX6jX9pHDaWMC8ep5Ji5HRW7ZcRG7Q2o/sTYTon/LnesFhC8Q95PRjrjIMi+BF
Xfsx915uHzp3Q9YaRZBg5To19oGvMYu5kxiXt3cRN+tZY2XvvcGpuz6K1wd/rBIS
UJ1QMeAsvJHX9T1gcKp87kJE88/BmZ/mMSdhPBAH4TzC3tsa2EtG49RYbZaCZcZR
i8WcAkJREhrETiAUk0uSTqfKxgElLZ5ZXU1rQHO+d08PI5f6s7GYYC6S+Xs3n3zM
jtBP6n2ehRFWW/SncHQfs7HGTVUNCGwZQ2zhC7N7jru3thdhRbdURwISW/5e5oSK
MYnQp1lRTU0TPnb/EI+Ng/FVFsSibrOYdv5ap3iooWw/yyWjLlNK/h5XKwARAQAB
tClDU1NTIFJlbGVhc2UgQm90IDxiYXNzZXJzZWNzZXRAcHJvdG9uLm1lPokCUgQT
AQoAPBYhBLOkwnJfRzcgZ0z4HgtJBInFly3BBQJpldpLAxsvBAULCQgHAgIiAgYV
CgkICwIEFgIDAQIeBwIXgAAKCRALSQSJxZctwXCsEACRIv/KJZITAvGvg+tI6Xg9
52qp/FLQIFYK89/098ap2SmTEPceGot5JqGCueXPuP/nFSddbuzkd36ENOD01K5r
dz/4arvyviRJeLoDsQ5eac0tjVkfQbDKa1m8Zgzkafu3yROi6CH06pnjI5/jV+f9
gTKVR1uttf/YtCq9bJmJqReYzDhZ5e9n9BTeANvnq8YpEMeookbZoySG3JVzDrc/
xyUjg71gF+cynstFAZ7WTohSS7Dyv6aFIazxLJtEVoPw7vH1+FApSc1W8WlpgG9k
iiHrkI3bDh+KPIoftxYtExHOtGHXxUnpcBGbw24j10wVxDyPvsEOKS9FMumESPhy
kHSewvnbmATeYd1bzFsyObeQXF8mq7ve7TMCfQ4jrKXi1PPkD11lNKzQbRhxDygO
QJHeRvbHS333HTqNRu2QwE7E/4GfYMs8vQG4C6VH75DeWAQ1T5pl8Fzb5/nrdYaq
d5a1HX2kswhqCtIO+YLOqEWLglV6K4rncVSWloxfMbItZWRQStppKc6zIqyZjPc8
hMxRBDfDoEuGLywRkhe+wHGTNwL/jlsnAeLUCXeLfX7AcFich2/DesYMa4uP+5Gz
PtG5Ptrs0OEAdvgH8PJh6EECgqEo5euMCsAIJ9dJ+JqPybklgfh8pYr6fmWYh5Fy
zP7PA7/9JmMKo4cf6OdqAw==
=GehJ
-----END PGP PUBLIC KEY BLOCK-----'

declare -a CLEANUP_COMMANDS=()
TMPARCHIVE=""
TMPSIGNATURE=""
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

trap 'installer::cleanup::int_handler' INT
trap 'installer::cleanup' EXIT

# Check if logger command is available for journal logging
command -v logger >/dev/null 2>&1 && readonly LOG_JOURNAL_ENABLED=1 || readonly LOG_JOURNAL_ENABLED=0

# @type:        Sink
# @description: Выводит сообщение с символом
# @params:      message - Сообщение для вывода
#               symbol - Символ для префикса
#               log_type - Тип лога для journal (SUCCESS, ERROR, INFO)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_generic() {
    # || true: stderr может быть закрыт или перенаправлен (например, при прерывании установки или через curl | bash)
    echo -e "$2 [$CURRENT_MODULE_NAME] $1" >&2 || true
    log::to_journal "$1" "$3"
}

# @type:        Source
# @description: Получает размер файла в KB
# @params:      file_path - Путь к файлу
# @stdin:       нет
# @stdout:      Размер файла в KB
# @exit_code:   0 - успешно
get_file_size_kb() {
    local file_path="$1"
    stat -c "%s" "$file_path" | gawk '{printf "%.2f KB\n", $1/1024}'
}

# @type:        Sink
# @description: Выполняет команду с обработкой ошибки
# @params:      command - Команда для выполнения (eval string)
#               error_key - Ключ перевода для сообщения об ошибке
#               error_args - Аргументы для сообщения об ошибке (опционально)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - команда выполнена успешно
#               1 - ошибка выполнения команды
run_or_error() {
    local command="$1"
    local error_key="$2"
    shift 2
    local error_args=("$@")

    if ! eval "$command"; then
        if [[ ${#error_args[@]} -gt 0 ]]; then
            log_error "$(_ "$error_key" "${error_args[@]}")"
        else
            log_error "$(_ "$error_key")"
        fi
        return 1
    fi
}

# @type:        Source
# @description: Создает временный файл с префиксом
# @params:      prefix - Префикс для временного файла
#               suffix - Суффикс (расширение) файла
# @stdin:       нет
# @stdout:      Путь к созданному временному файлу
# @exit_code:   0 - успешно
#               1 - ошибка создания
mktemp_with_prefix() {
    local prefix="$1"
    local suffix="$2"
    local tmpfile
    tmpfile=$(mktemp --tmpdir "$prefix"-XXXXXX"$suffix") || return 1
    printf '%s' "$tmpfile"
}

# @type:        Source
# @description: Загружает файл по URL во временный файл
# @params:      url - URL для загрузки
#               tmpfile - Путь к временному файлу (если не указан, создается автоматически)
#               prefix - Префикс для создания временного файла
#               suffix - Суффикс для создания временного файла
#               start_log_key - Ключ перевода для сообщения о начале загрузки
#               success_log_key - Ключ перевода для сообщения об успешной загрузке
#               error_log_key - Ключ перевода для сообщения об ошибке
#               add_to_cleanup - Добавлять в CLEANUP_COMMANDS (default: true)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка загрузки
install::download::generic() {
    local url="$1"
    local tmpfile="${2:-}"
    local prefix="${3:-$UTIL_NAME}"
    local suffix="${4:-}"
    local start_log_key="$5"
    local success_log_key="$6"
    local error_log_key="$7"
    local add_to_cleanup="${8:-true}"

    if [[ -z "$tmpfile" ]]; then
        tmpfile=$(mktemp_with_prefix "$prefix" "$suffix") || return 1
    fi

    log_info "$(_ "$start_log_key" "$url")"

    if [[ "$add_to_cleanup" == "true" ]]; then
        CLEANUP_COMMANDS+=("$tmpfile")
    fi

    if ! curl -fL --progress-meter "$url" -o "$tmpfile"; then
        log_error "$(_ "$error_log_key")"
        rm -f "$tmpfile" 2>/dev/null || true
        return 1
    fi

    local fsize
    fsize=$(get_file_size_kb "$tmpfile")
    log_info "$(_ "$success_log_key" "$tmpfile" "$fsize" "$(file -ib "$tmpfile")")"

    printf '%s' "$tmpfile"
}

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
        # || true: Logger может не справиться с логированием в критических ситуациях (например, при закрытых дескрипторах)
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
    log_generic "$1" "$SYMBOL_SUCCESS" "SUCCESS"
}

# @type:        Sink
# @description: Выводит сообщение об ошибке с символом [x]
# @params:      message - Сообщение об ошибке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_error() {
    log_generic "$1" "$SYMBOL_ERROR" "ERROR"
}

# @type:        Sink
# @description: Выводит информационное сообщение с символом [ ]
# @params:      message - Информационное сообщение
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_info() {
    log_generic "$1" "$SYMBOL_INFO" "INFO"
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
        log_question "$question [$hint]"
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] $question [$hint]: " -r choice
        choice=${choice:-$default}
        log_answer "$choice"

        # Возвращаем код 2 при отмене
        [[ -n "$cancel_keyword" && "$choice" == "$cancel_keyword" ]] && return 2

        if [[ "$choice" =~ ^$pattern$ ]]; then
            printf '%s\n' "$choice"
            break
        fi
        log_error "$(_ "error_invalid_input" "[$hint]")"
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
    lang=$(installer::ask_value "$(_ "no_translate" "Русский [r] | English [e]")" "r" "[re]" "r/e" | tr -d '\0')

    if [[ "$lang" =~ ^[Ee]$ ]]; then
        INSTALLER_LANG="en"
    else
        INSTALLER_LANG="ru"
    fi

    log_info "$(_ "ask_language.selected") [$INSTALLER_LANG]"
}

# @type:        Sink
# @description: Выводит приветственное сообщение
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
installer::ui::hello() {
    log_info "$(_ "hello" "${UTIL_NAME^^}")"
}

# @type:        Filter
# @description: Проверяет права root
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - права root есть
#               1 - недостаточно прав
installer::check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "$(_ "error_root_required")"
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
installer::ui::ask_run_mode() {
    local choice
    choice=$(installer::ask_value "$(_ "ask_run_mode.prompt")" "y" "[yic]" "Y/i/c" "c" | tr -d '\0')

    if [[ $choice =~ ^[Ii]$ ]]; then
        log_info "$(_ "ask_run_mode.install" "$choice")"
        if [[ -d "$INSTALL_DIR" ]]; then
            log_error "$(_ "error_already_installed")"
            log_info "$(_ "info_installed_usage")"
            log_info "$(_ "info_installed_uninstall")"
            return 1
        fi
        SYS_INSTALL_FLAG=1
    elif [[ $choice =~ ^[Yy]$ ]]; then
        log_info "$(_ "ask_run_mode.onetime" "$choice")"
        ONETIME_RUN_FLAG=1
    fi
}

# @type:        Orchestrator
# @description: Выполняет полный цикл GPG-верификации: импорт ключа, загрузка подписи, проверка
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка (non-critical, операции с || true)
installer::gpg::verify_workflow() {
    install::gpg::import_public_key || true
    install::download::signature || true
    if [[ -n "$TMPSIGNATURE" && -f "$TMPSIGNATURE" ]]; then
        install::gpg::verify || true
    fi
}

# @type:        Orchestrator
# @description: Устанавливает GPG через apt и запускает верификацию
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка установки
installer::gpg::install() {
    log_info "$(_ "gpg.installing")"

    if ! apt-get update >/dev/null 2>&1; then
        log_error "$(_ "gpg.apt_update_failed")"
        return 1
    fi

    if ! apt-get install -y gnupg >/dev/null 2>&1; then
        log_error "$(_ "gpg.install_failed")"
        return 1
    fi

    log_success "$(_ "gpg.installed")"

    if install::gpg::check_available; then
        installer::gpg::verify_workflow
    else
        log_error "$(_ "gpg.install_failed")"
        return 1
    fi
}

# @type:        Interactive
# @description: Запрашивает подтверждение и устанавливает GPG через apt
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - GPG установлен или уже доступен
#               1 - пользователь отказался или ошибка установки
installer::gpg::ask_and_install() {
    local choice
    choice=$(installer::ask_value "$(_ "gpg.ask_install")" "y" "[yn]" "Y/n" | tr -d '\0')

    if [[ $choice =~ ^[Nn]$ ]]; then
        log_info "$(_ "gpg.install_declined")"
        return 1
    fi

    installer::gpg::install
}

# @type:        Orchestrator
# @description: Подготавливает окружение для запуска или установки: временную директорию, архив, распаковку и проверку
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка подготовки
installer::prepare() {
    install::tmp::create
    install::download::archive

    if install::gpg::check_available; then
        installer::gpg::verify_workflow
    else
        installer::gpg::ask_and_install || return 1
    fi

    install::archive::unpack "$TMPARCHIVE" "$TEMP_PROJECT_DIR"
    install::archive::check "$TEMP_PROJECT_DIR" "$MAIN_SCRIPT_FILE_NAME"
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

    log_info "$(_ "tmpdir.created" "$temp_dir")"
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

    tmparchive=$(install::download::generic \
        "$archive_url" \
        "$tmparchive" \
        "$UTIL_NAME" \
        "-archive.tar.gz" \
        "download.start" \
        "downloaded" \
        "download.failed" \
        "$add_to_cleanup") || return 1

    TMPARCHIVE="$tmparchive"
}

# @type:        Validator
# @description: Check if gpg command is available
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - gpg available
#               1 - gpg not available
install::gpg::check_available() {
    command -v gpg >/dev/null 2>&1
}

# @type:        Source/Sink
# @description: Import embedded public GPG key into keyring
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - success
#               1 - import failed (non-critical)
install::gpg::import_public_key() {
    local import_output
    import_output=$(printf '%s' "$GPG_PUBLIC_KEY_ASCII" | gpg --import 2>&1) || {
        log_error "$(_ "gpg.import_failed" "$import_output")"
        return 1
    }
    log_info "$(_ "gpg.imported")"
}

# @type:        Source
# @description: Download .asc signature file from GitHub
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - success
#               1 - download failed (non-critical)
install::download::signature() {
    local tmpsignature

    tmpsignature=$(install::download::generic \
        "$SIGNATURE_URL" \
        "" \
        "$UTIL_NAME" \
        "-signature.asc" \
        "gpg.download_start" \
        "gpg.downloaded" \
        "gpg.download_failed") || return 1

    TMPSIGNATURE="$tmpsignature"
}

# @type:        Filter
# @description: Verify archive signature
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - valid signature
#               1 - invalid signature (non-critical)
install::gpg::verify() {
    local verify_output

    log_info "$(_ "gpg.verify_start")"

    verify_output=$(gpg --verify "$TMPSIGNATURE" "$TMPARCHIVE" 2>&1) || {
        log_error "$(_ "gpg.verify_failed")"
        log_info "$(_ "no_translate" "GPG verification output: $verify_output")"
        log_error "$(_ "gpg.continuing_unverified")"
        return 1
    }

    log_info "$(_ "gpg.verify_success")"
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
        log_error "$(_ "unpack.failed" "$tar_output")"
        return 1
    }
    local dir_size
    dir_size=$(du -sb "$temp_project_dir" | cut -f1 | gawk '{printf "%.2f KB\n", $1/1024}' )
    log_info "$(_ "unpacked" "$temp_project_dir" "$dir_size")"
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
        log_error "$(_ "check.not_found" "$main_script_file_name")"
        return 1
    fi
    log_info "$(_ "check.found" "$main_script_file_name")"
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
    installer::write_lang
    install::symlink::create
    installer::set_permissions

    log_success "$(_ "install.complete")"
    log_info "$(_ "install.usage" "$UTIL_NAME" "$UTIL_NAME")"
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
        log_error "$(_ "symlink.exists" "$UTIL_NAME")"
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

    log_info "$(_ "dir.creating" "$install_dir")"
    run_or_error "mkdir -p \"$install_dir\"" "dir.create_failed" "$install_dir" || return 1
    installer::log::add_path "$install_dir"
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

    log_info "$(_ "files.copying" "$tmp_dir_path" "$install_dir")"
    run_or_error "cp -r \"$tmp_dir_path\"/* \"$install_dir/\"" "files.copy_failed" || return 1
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
installer::log::add_path() {
    local uninstall_path="${1:-}"
    local install_log_path="${2:-$INSTALL_DIR/$INSTALL_LOG_FILE_NAME}"

    if [[ -z "$uninstall_path" ]]; then
        log_error "$(_ "log.no_path")"
        return 1
    fi

    if ! grep -Fxq "$uninstall_path" "$install_log_path" 2>/dev/null; then
        echo "$uninstall_path" >> "$install_log_path"
        log_info "$(_ "log.path_added" "$uninstall_path" "$install_log_path")"
    fi
}

# @type:        Sink
# @description: Запись/перезапись файла .lang (код без переноса строки)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка записи файла
installer::write_lang() {
    [[ -n "$INSTALLER_LANG" ]] && printf '%s' "$INSTALLER_LANG" > "$LANG_FILE"
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

    run_or_error "ln -s \"$main_script_path\" \"$symbol_link_path\"" "symlink.create_failed" || return 1

    log_info "$(_ "symlink.created" "$util_name" "$main_script_path" "$(dirname "$symbol_link_path")")"
    installer::log::add_path "$symbol_link_path"
}

# @type:        Orchestrator
# @description: Установка прав на выполнение
# @params:
#   install_dir [optional] Директория установки (default: $INSTALL_DIR)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
installer::set_permissions() {
    local install_dir="${1:-$INSTALL_DIR}"

    log_info "$(_ "permissions.setting" "$install_dir")"
    # chmod +x "$install_dir"/*.sh 2>/dev/null
    chmod a+rwx,o+t "$install_dir" 2>/dev/null

}

# @type:        Sink
# @description: Обработчик прерывания INT
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
installer::cleanup::int_handler() {
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        rc=130
    fi
    echo >&2
    log_info "$(_ "no_translate" "Сигнал прерывания [RC: $rc]")"
}

# @type:        Orchestrator
# @description: Очистка временных файлов
# @params:
#   reason      Причина очистки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
installer::cleanup() {
    local rc=$?
    

    if [ "$CLEANUP_DONE_FLAG" -eq 1 ]; then
        return 0
    fi

    log_info "$(_ "cleanup.start" "[RC: $rc]")"

    if [[ "${#CLEANUP_COMMANDS[@]}" -eq 0 ]]; then
        log_info "$(_ "cleanup.nothing_to_cleanup")"
    fi

    local i
    for i in "${!CLEANUP_COMMANDS[@]}"; do
        local cmd
        cmd="${CLEANUP_COMMANDS[$i]}"
        log_info "$(_ "cleanup.removing" "$cmd")"
        rm -rf $cmd
        unset 'CLEANUP_COMMANDS[$i]'
    done
    log_success "$(_ "cleanup.complete")"
    CLEANUP_DONE_FLAG=1
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка выполнения
installer::main() {
    log_info "$(_ "no_translate" "For logs type [journalctl -t bsss --since '10 minutes ago']")"
    installer::ui::ask_language
    installer::ui::hello
    installer::check_root
    installer::ui::ask_run_mode

    if [[ "$ONETIME_RUN_FLAG" -eq 1 ]]; then
        installer::prepare
        bash "$TMP_MAIN_SCRIPT_PATH" -l "$INSTALLER_LANG"
    fi
    if [[ "$SYS_INSTALL_FLAG" -eq 1 ]]; then
        log_info "$(_ "install.info.download_archive" "${UTIL_NAME^^}" "$ARCHIVE_URL")"
        log_info "$(_ "install.info.install_dir" "${UTIL_NAME^^}" "$INSTALL_DIR")"
        log_info "$(_ "install.info.usage_run" "$UTIL_NAME")"
        installer::ask_value "$(_ "continue")" "y" "[yn]" "Y/n" "n"

        installer::prepare
        install::to_system
    fi
}

# Russian translations
declare -gA I18N_MESSAGES_RU=(
    [no_translate]="%s"
    [continue]="Продолжить?"
    [hello]="Basic Server Security Setup (%s) - oneline запуск..."
    [ask_language.selected]="Выбран язык"
    [error_invalid_input]="Неверный выбор"
    [cleanup.start]="Запуск процедуры очистки: %s"
    [cleanup.nothing_to_cleanup]="Очистка не требуется - ничего не было установлено/распаковано"
    [cleanup.removing]="Удаляю: %s"
    [cleanup.complete]="Очистка завершена"
    [error_root_required]="Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
    [ask_run_mode.prompt]="Разовый запуск [Y] | Установка [i] | Отмена [c]"
    [ask_run_mode.invalid]="Неверный выбор [%s]. Пожалуйста, выберите [yic]"
    [ask_run_mode.cancelled]="Выбрана отмена (%s)"
    [ask_run_mode.install]="Выбрана установка (%s)"
    [ask_run_mode.onetime]="Выбран разовый запуск (%s)"
    [error_already_installed]="Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
    [info_installed_usage]="Для запуска Basic Server Security Setup (${UTIL_NAME^^}) используйте команду: sudo ${UTIL_NAME}, если не сработает - проверьте, что установлено в каталоге ${INSTALL_DIR} или куда ссылается ссылка ${UTIL_NAME} [find /bin /usr/bin /usr/local/bin -type l -ls | grep ${UTIL_NAME}] или [realpath ${UTIL_NAME}]"
    [info_installed_uninstall]="Для удаления ранее установленного скрипта ${UTIL_NAME^^} выполните: sudo ${UTIL_NAME} -u"
    [tmpdir.created]="Создана временная директория %s"
    [download.start]="Скачиваю архив: %s"
    [download.failed]="Не удалось скачать архив (проверьте интернет или URL)"
    [downloaded]="Архив скачан в %s (размер: %s, тип: %s)"
    [unpack.failed]="Ошибка распаковки архива - %s"
    [unpacked]="Архив распакован в %s (размер: %s)"
    [check.not_found]="При проверке наличия исполняемого файла произошла ошибка - файл %s не найден - что то не так... либо ошибка при рапаковке архива, либо ошибка в путях."
    [check.found]="Исполняемый файл %s найден"
    [log.no_path]="Не указан путь для добавления в лог удаления"
    [log.path_added]="Путь %s добавлен в лог удаления %s"
    [symlink.exists]="Символическая ссылка %s уже существует"
    [dir.creating]="Создаю директорию %s"
    [dir.create_failed]="Не удалось создать директорию %s"
    [files.copying]="Копирую файлы из %s в %s"
    [files.copy_failed]="Не удалось скопировать файлы"
    [symlink.create_failed]="Не удалось создать символическую ссылку"
    [symlink.created]="Создана символическая ссылка %s для запуска %s. (Расположение ссылки: %s)"
    [permissions.setting]="Устанавливаю права запуска (+x) в %s для .sh файлов"
    [install.start]="Устанавливаю %s в систему..."
    [install.complete]="Установка в систему завершена"
    [install.usage]="Используйте для запуска: sudo %s, для удаления: sudo %s -u"
    [install.info.download_archive]="Будет скачан архив последней версии релиза %s [%s]"
    [install.info.install_dir]="Будет произведена установка %s в директорию [%s]"
    [install.info.usage_run]="Запускать sudo %s"
    [gpg.import_failed]="Ошибка импорта GPG ключа: %s"
    [gpg.imported]="Публичный GPG ключ импортирован [gpg --import]"
    [gpg.download_start]="Загрузка подписи GPG: %s"
    [gpg.download_failed]="Ошибка загрузки подписи: %s"
    [gpg.downloaded]="Подпись скачана: %s (%s, %s)"
    [gpg.verify_start]="Проверка GPG подписи..."
    [gpg.verify_failed]="GPG подпись НЕВЕРНА! Подробности в журнале."
    [gpg.verify_success]="GPG подпись верна"
    [gpg.continuing_unverified]="Установка продолжается без верификации. Риск подмены архива."
    [gpg.ask_install]="GPG не установлен. Установить GPG для проверки подписи?"
    [gpg.install_declined]="Установка GPG отклонена. Продолжение без проверки подписи."
    [gpg.installing]="Установка GPG через apt..."
    [gpg.installed]="GPG успешно установлен"
    [gpg.apt_update_failed]="Ошибка обновления индексов apt"
    [gpg.install_failed]="Ошибка установки GPG через apt"
)

# English translations
declare -gA I18N_MESSAGES_EN=(
    [no_translate]="%s"
    [continue]="Continue?"
    [hello]="Basic Server Security Setup (%s) - oneline execution..."
    [ask_language.selected]="Language selected"
    [error_invalid_input]="Invalid choice"
    [cleanup.start]="Starting cleanup procedure: %s"
    [cleanup.nothing_to_cleanup]="Cleanup not required - nothing was installed/unpacked"
    [cleanup.removing]="Removing: %s"
    [cleanup.complete]="Cleanup completed"
    [error_root_required]="Root privileges required or run via 'sudo'. Running as regular user."
    [ask_run_mode.prompt]="One-time run [Y] | Install [i] | Cancel [c]"
    [ask_run_mode.invalid]="Invalid choice [%s]. Please choose [yic]"
    [ask_run_mode.cancelled]="Cancel selected (%s)"
    [ask_run_mode.install]="Install selected (%s)"
    [ask_run_mode.onetime]="One-time run selected (%s)"
    [error_already_installed]="Script already installed in the system or another script with the same directory name is installed."
    [info_installed_usage]="To launch Basic Server Security Setup (${UTIL_NAME^^}), use the command: sudo ${UTIL_NAME}. If it doesn't work, verify the installation directory is ${INSTALL_DIR} or check where the symlink points: ${UTIL_NAME} [find /bin /usr/bin /usr/local/bin -type l -ls | grep ${UTIL_NAME}] or [realpath ${UTIL_NAME}]"
    [info_installed_uninstall]="To uninstall previously installed script ${UTIL_NAME^^} run: sudo ${UTIL_NAME} -u"
    [tmpdir.created]="Created temporary directory %s"
    [download.start]="Downloading archive: %s"
    [download.failed]="Failed to download archive (check internet or URL)"
    [downloaded]="Archive downloaded to %s (size: %s, type: %s)"
    [unpack.failed]="Archive unpack error - %s"
    [unpacked]="Archive unpacked to %s (size: %s)"
    [check.not_found]="Error checking executable file - file %s not found - something is wrong... either archive unpack error or path error."
    [check.found]="Executable file %s found"
    [log.no_path]="Path not specified for uninstall log"
    [log.path_added]="Path %s added to uninstall log %s"
    [symlink.exists]="Symbolic link %s already exists"
    [dir.creating]="Creating directory %s"
    [dir.create_failed]="Failed to create directory %s"
    [files.copying]="Copying files from %s to %s"
    [files.copy_failed]="Failed to copy files"
    [symlink.create_failed]="Failed to create symbolic link"
    [symlink.created]="Created symbolic link %s for running %s. (Link location: %s)"
    [permissions.setting]="Setting execute permissions (+x) in %s for .sh files"
    [install.start]="Installing %s to system..."
    [install.complete]="System installation completed"
    [install.usage]="Use to run: sudo %s, to uninstall: sudo %s -u"
    [install.info.download_archive]="Will download the latest release archive of %s [%s]"
    [install.info.install_dir]="Will install %s to directory [%s]"
    [install.info.usage_run]="Run with sudo %s"
    [gpg.import_failed]="Failed to import GPG key: %s"
    [gpg.imported]="Public GPG key imported [gpg --import]"
    [gpg.download_start]="Downloading GPG signature: %s"
    [gpg.download_failed]="Failed to download signature: %s"
    [gpg.downloaded]="Signature downloaded: %s (%s, %s)"
    [gpg.verify_start]="Verifying GPG signature..."
    [gpg.verify_failed]="GPG signature INVALID! Details in journal."
    [gpg.verify_success]="GPG signature is valid"
    [gpg.continuing_unverified]="Installation continues without verification. Risk of tampered archive."
    [gpg.ask_install]="GPG not installed. Install GPG for signature verification?"
    [gpg.install_declined]="GPG installation declined. Continuing without signature verification."
    [gpg.installing]="Installing GPG via apt..."
    [gpg.installed]="GPG installed successfully"
    [gpg.apt_update_failed]="Error updating apt indexes"
    [gpg.install_failed]="Error installing GPG via apt"
)

installer::main
