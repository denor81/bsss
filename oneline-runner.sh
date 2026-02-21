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
tClCU1NTIFJlbGVhc2UgQm90IDxiYXNzZXJzZWNzZXRAcHJvdG9uLm1lPokCUgQT
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
TEMP_PROJECT_DIR=""
TMPARCHIVE=""
TMPSIGNATURE=""
TMP_MAIN_SCRIPT_PATH=""
CLEANUP_DONE_FLAG=0
INSTALLER_LANG=""

readonly SYMBOL_SUCCESS="[v]"
readonly SYMBOL_QUESTION="[?]"
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[x]"
readonly SYMBOL_WARN="[!]"

# Journal mapping: BSSS log type -> systemd journal priority
readonly -A JOURNAL_MAP=(
    [SUCCESS]="notice"
    [INFO]="info"
    [ERROR]="err"
    [WARN]="warning"
)

trap 'install::cleanup::int_handler' INT
trap 'install::cleanup' EXIT

# Check if logger command is available for journal logging
command -v logger >/dev/null 2>&1 && readonly LOG_JOURNAL_ENABLED=1 || readonly LOG_JOURNAL_ENABLED=0

#########################################
#                                       #
#                                       #
#                                       #
#                 INIT                  #
#                                       #
#                                       #
#                                       #
#########################################
# @type:        Filter
# @description: Проверяет права root
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - права root есть
#               1 - недостаточно прав
init::check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "$(_ "error_root_required")"
        return 1
    fi
}

# @type:        Filter
# @description: Проверяет установлен ли скрипт уже
# @params:
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - не установлен (можно устанавливать)
#               1 - установлен (нельзя продолжать)
init::allready_installed() {
    if [[ -d "$INSTALL_DIR" ]] || [[ -L "$SYMBOL_LINK_PATH" ]]; then
        log_error "$(_ "error_already_installed")"
        log_info "$(_ "info_installed_usage")"
        log_info "$(_ "info_installed_uninstall")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Проверяет и устанавливает зависимости (GPG)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - зависимости в порядке
#               $? - ошибка установки зависимостей
init::check_dependencies() {
    if ! command -v gpg &>/dev/null; then
        ui::ask_value "$(_ "gpg.ask_install")" "y" "[yn]" "Y/n" "[n0]" >/dev/null
        init::gpg::install
    fi
}

# @type:        Orchestrator
# @description: Устанавливает GPG через apt
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка установки
init::gpg::install() {
    log_info "$(_ "gpg.installing")"

    if ! apt-get update >/dev/null; then
        log_error "$(_ "apt_update_failed")"
        return 1
    fi

    if ! apt-get install -y gnupg; then
        log_error "$(_ "gpg.install_failed")"
        return 1
    fi

    log_success "$(_ "gpg.installed")"
}

# @type:        Sink
# @description: Запрашивает у пользователя язык установки
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - язык выбран
# @type:        Sink
# @description: Запрашивает у пользователя язык установки
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - язык выбран
#               1 - ошибка выбора языка
#               2 - отмена пользователем
init::ask_language() {
    local lang
    local hint="r/e"
    lang=$(ui::ask_value "$(_ "no_translate" "Русский [r] | English [e]")" "r" "[re]" "$hint" "[c0]") || return

    case "${lang,,}" in
        e) INSTALLER_LANG="en" ;;
        r) INSTALLER_LANG="ru" ;;
        *) log_error "$(_ "error_invalid_input" "$hint")"; return 1 ;;
    esac

    log_info "$(_ "ask_language.selected" "$INSTALLER_LANG")"
}
#########################################
#                                       #
#                                       #
#                                       #
#                 /INIT                 #
#                                       #
#                                       #
#                                       #
#########################################

#########################################
#                                       #
#                                       #
#                                       #
#               HELPERS                 #
#                                       #
#                                       #
#                                       #
#########################################
# @type:        Source
# @description: Получает размер файла в KB
# @params:      file_path\n
# @stdin:       нет
# @stdout:      Размер файла в KB
# @exit_code:   0 - успешно
get_file_size_kb() {
    numfmt --to-unit=1024 --format="%.2f KB" "$(stat -c "%s" "$1")"
}

# @type:        Sink
# @description: Добавляет путь в файл лога установки для последующего удаления
# @params:
#   uninstall_path Путь для добавления в лог удаления
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
add_path_for_uninstall() {
    local uninstall_path="$1"
    local install_log_path="${INSTALL_DIR}/${INSTALL_LOG_FILE_NAME}"

    if ! grep -Fxq "$uninstall_path" "$install_log_path" 2>/dev/null; then
        echo "$uninstall_path" >> "$install_log_path"
        log_info "$(_ "log.path_added" "$uninstall_path" "$install_log_path")"
    fi
}

# @type:        Orchestrator
# @description: Создание директории установки
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка создания
install::dir::create() {
    log_info "$(_ "dir.creating" "$INSTALL_DIR")"
    mkdir -p "$INSTALL_DIR" || { log_error "$(_ "dir.create_failed" "$INSTALL_DIR")"; return 1; }
    add_path_for_uninstall "$INSTALL_DIR"
}
#########################################
#                                       #
#                                       #
#                                       #
#               /HELPERS                #
#                                       #
#                                       #
#                                       #
#########################################

#########################################
#                                       #
#                                       #
#                                       #
#                  LOG                  #
#                                       #
#                                       #
#                                       #
#########################################
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
# @description: Выводит сообщение с предупреждением с символом [!]
# @params:      message - Сообщение об ошибке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_warn() {
    log_generic "$1" "$SYMBOL_WARN" "WARN"
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
    log::to_journal "$1" "QUESTION"
}

# @type:        Sink
# @description: ТОЛЬКО в файл - ответ с символом [?]
#               В терминал ответ выводится стандартными средствами read
# @params:      answer
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_answer() {
    log::to_journal "$1" "ANSWER"
}
#########################################
#                                       #
#                                       #
#                                       #
#                 /LOG                  #
#                                       #
#                                       #
#                                       #
#########################################

#########################################
#                                       #
#                                       #
#                                       #
#                 I18N                  #
#                                       #
#                                       #
#                                       #
#########################################
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

# Russian translations
declare -gA I18N_MESSAGES_RU=(
    [no_translate]="%s"
    [continue]="Продолжить?"
    [canceled]="Отменено"
    [hello]="Базовая настройка безопасности сервера/Basic Server Security Setup (${UTIL_NAME^^}) - однострочный запуск..."
    [ask_language.selected]="Выбран язык [%s]"
    [error_invalid_input]="Неверный выбор [%s]"
    [cleanup.start]="Запуск процедуры очистки: [RC: %s]"
    [cleanup.nothing_to_cleanup]="Очистка не требуется - ничего не было установлено/распаковано"
    [cleanup.removing]="Удаляю: %s"
    [cleanup.complete]="Очистка завершена"
    [error_root_required]="Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
    [run_mode.dispatcher.prompt]="Разовый запуск [Y] | Установка [i] | Отмена [c]"
    [error_already_installed]="Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
    [info_installed_usage]="Для запуска Basic Server Security Setup (${UTIL_NAME^^}) используйте команду: sudo ${UTIL_NAME}, если не сработает - проверьте, что установлено в каталоге ${INSTALL_DIR} или куда ссылается ссылка ${UTIL_NAME} [find /bin /usr/bin /usr/local/bin -type l -ls | grep ${UTIL_NAME}]"
    [info_installed_uninstall]="Для удаления ранее установленного скрипта ${UTIL_NAME^^} выполните: sudo ${UTIL_NAME} -u"
    [tmpdir.created]="Создана временная директория %s"
    [download.failed]="Не удалось скачать (проверьте интернет или URL) [%s]"
    [downloaded]="Скачан в %s (размер: %s, тип: %s)"
    [unpack.failed]="Ошибка распаковки архива - %s"
    [unpacked]="Архив распакован в %s (размер: %s)"
    [check.not_found]="При проверке наличия исполняемого файла произошла ошибка - файл %s не найден - что то не так... либо ошибка при рапаковке архива, либо ошибка в путях."
    [check.found]="Исполняемый файл %s найден"
    [log.path_added]="Путь %s добавлен в лог удаления %s"
    [dir.creating]="Создаю директорию %s"
    [dir.create_failed]="Не удалось создать директорию %s"
    [files.copying]="Копирую файлы из %s в %s"
    [symlink.created]="Создана символическая ссылка $UTIL_NAME для запуска %s. (Расположение ссылки: %s)"
    [permissions.setting]="Устанавливаю права запуска (+x) в %s для .sh файлов"
    [install.complete]="Установка в систему завершена"
    [install.usage]="Используйте для запуска: sudo $UTIL_NAME, для удаления: sudo $UTIL_NAME -u"
    [install.info.download_archive]="Будет скачан архив последней версии релиза ${UTIL_NAME^^} [%s]"
    [install.info.download_signature]="Будет скачана подпись для верификации архива ${UTIL_NAME^^} [%s]"
    [install.info.install_dir]="Будет произведена установка ${UTIL_NAME^^} в директорию [%s]"
    [install.info.usage_run]="Запускать sudo $UTIL_NAME"
    [gpg.import_failed]="Ошибка импорта GPG ключа: [%s]"
    [gpg.imported]="Публичный GPG ключ импортирован [gpg --import] [%s]"
    [gpg.verify_start]="Проверка GPG подписи..."
    [gpg.verify_failed]="GPG подпись НЕВЕРНА! Подробности в журнале."
    [gpg.verify_success]="GPG подпись верна"
    [gpg.ask_install]="GPG не установлен. Установить GPG для проверки подписи?"
    [gpg.installing]="Установка GPG через apt..."
    [gpg.installed]="GPG успешно установлен"
    [apt_update_failed]="Ошибка обновления индексов apt"
    [gpg.install_failed]="Ошибка установки GPG через apt"
)

#########################################
#                                       #
#                                       #
#                                       #
#                  UI                   #
#                                       #
#                                       #
#                                       #
#########################################
# @type:        Interactive
# @description: Запрашивает у пользователя значение
# @params:      question - Вопрос
#               default - Значение по умолчанию
#               pattern - Regex паттерн ожидаемого ввода
#               hint - Подсказка какие значения ожидаются
# @stdin:       Ожидает ввод пользователя (TTY)
# @stdout:      string\n
# @exit_code:   0 - успешно
#               2 - отмена пользователем
ui::ask_value() {
    local question="$1" default="$2" pattern="$3" hint="$4" cancel_keyword="${5:-}"
    local choice

    while true; do
        log_question "$question [$hint]"
        read -p "$SYMBOL_QUESTION [$CURRENT_MODULE_NAME] $question [$hint]: " -r choice
        choice=${choice:-$default}
        log_answer "$choice"

        # Возвращаем код 2 при отмене
        [[ -n "$cancel_keyword" && "$choice" =~ ^$cancel_keyword$ ]] && { log_warn "$(_ "canceled")"; return 2; }

        if [[ "$choice" =~ ^$pattern$ ]]; then
            printf '%s\n' "$choice"
            break
        fi
        log_error "$(_ "error_invalid_input" "$hint")"
    done
}
#########################################
#                                       #
#                                       #
#                                       #
#                  /UI                  #
#                                       #
#                                       #
#                                       #
#########################################

#########################################
#                                       #
#                                       #
#                                       #
#                 LOGIC                 #
#                                       #
#                                       #
#                                       #
#########################################
# @type:        Orchestrator
# @description: Оркестратор установки: подтверждение, подготовка и установка в систему
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка установки
install::orchestrator() {
    log_info "$(_ "install.info.install_dir" "$INSTALL_DIR")"
    log_info "$(_ "install.info.usage_run")"

    ui::ask_value "$(_ "continue")" "y" "[yn]" "Y/n" "[c0n]" >/dev/null
    install::prepare
    install::to_system
}

# @type:        Orchestrator
# @description: Оркестратор разового запуска: подготовка и запуск main.sh
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка выполнения
onetime_runner::orchestrator() {
    install::prepare
    bash "$TMP_MAIN_SCRIPT_PATH" -l "$INSTALLER_LANG"
}

# @type:        Interactive
# @description: Запрашивает у пользователя режим запуска (однократно/установка/отмена)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - режим выбран и выполнен
#               1 - ошибка выбора или выполнения
#               2 - отмена пользователем
install::dispatcher() {
    local choice
    local hint="Y/i/c"

    log_info "$(_ "install.info.download_archive" "$ARCHIVE_URL")"
    log_info "$(_ "install.info.download_signature" "$SIGNATURE_URL")"

    choice=$(ui::ask_value "$(_ "run_mode.dispatcher.prompt")" "y" "[yic]" "$hint" "[c0]") || return

    case "${choice,,}" in
        y) onetime_runner::orchestrator ;;
        i) init::allready_installed && install::orchestrator ;;
        *) log_error "$(_ "error_invalid_input" "$hint")"; return 1 ;;
    esac
}
#########################################
#                                       #
#                                       #
#                                       #
#                 /LOGIC                #
#                                       #
#                                       #
#                                       #
#########################################

#########################################
#                                       #
#                                       #
#                                       #
#                PREPARE                #
#                                       #
#                                       #
#                                       #
#########################################
# @type:        Orchestrator
# @description: Подготавливает окружение для запуска или установки: временную директорию, архив, распаковку и проверку
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка подготовки
install::prepare() {
    install::tmp::create

    install::download::archive
    install::download::signature

    install::verify_archive

    install::archive::unpack
    install::archive::check
}

# @type:        Sink
# @description: Создаёт временную директорию и сохраняет путь в глобальную переменную
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка создания директории
install::tmp::create() {
    TEMP_PROJECT_DIR=$(mktemp -d --tmpdir "${UTIL_NAME}"-XXXXXX) || return 1
    CLEANUP_COMMANDS+=("$TEMP_PROJECT_DIR")
    log_info "$(_ "tmpdir.created" "$TEMP_PROJECT_DIR")"
}

# @type:        Sink
# @description: Скачивает архив и сохраняет путь в глобальную переменную TMPARCHIVE
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка скачивания
install::download::archive() {
    TMPARCHIVE=$(mktemp --tmpdir "${UTIL_NAME}"-XXXXXX-archive.tar.gz) || return 1
    CLEANUP_COMMANDS+=("$TMPARCHIVE")
    if curl -fSL --progress-meter "$ARCHIVE_URL" -o "$TMPARCHIVE"; then
        local f_size=$(get_file_size_kb "$TMPARCHIVE")
        local f_type=$(file -ib "$TMPARCHIVE")
        log_info "$(_ "downloaded" "$TMPARCHIVE" "$f_size" "$f_type")"
    else
        log_error "$(_ "download.failed" "$ARCHIVE_URL")"
        return 1
    fi
}


# @type:        Sink
# @description: Скачивает подпись и сохраняет путь в глобальную переменную TMPSIGNATURE
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка скачивания
install::download::signature() {
    TMPSIGNATURE=$(mktemp --tmpdir "${UTIL_NAME}"-XXXXXX-signature.asc) || return 1
    CLEANUP_COMMANDS+=("$TMPSIGNATURE")
    if curl -fSL --progress-meter "$SIGNATURE_URL" -o "$TMPSIGNATURE"; then
        local f_size=$(get_file_size_kb "$TMPSIGNATURE")
        local f_type=$(file -ib "$TMPSIGNATURE")
        log_info "$(_ "downloaded" "$TMPSIGNATURE" "$f_size" "$f_type")"
    else
        log_error "$(_ "download.failed" "$ARCHIVE_URL")"
        return 1
    fi
}

# @type:        Filter
# @description: Распаковывает архив
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка распаковки
install::archive::unpack() {
    local dir_size
    tar -xzf "$TMPARCHIVE" -C "$TEMP_PROJECT_DIR" 2>&1 || { log_error "$(_ "unpack.failed" "$TMPARCHIVE")"; return 1; }
    dir_size=$(du -sb "$TEMP_PROJECT_DIR" | cut -f1 | numfmt --to-unit=1024 --format="%.2f KB")
    log_info "$(_ "unpacked" "$TEMP_PROJECT_DIR" "$dir_size")"
}

# @type:        Filter
# @description: Проверяет успешность распаковки во временную директорию
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - файл найден
#               1 - файл не найден
install::archive::check() {
    TMP_MAIN_SCRIPT_PATH="$(find "$TEMP_PROJECT_DIR" -type f -name "$MAIN_SCRIPT_FILE_NAME")"
    if [[ -z "$TMP_MAIN_SCRIPT_PATH" ]]; then
        log_error "$(_ "check.not_found" "$MAIN_SCRIPT_FILE_NAME")"
        return 1
    fi
    log_info "$(_ "check.found" "$MAIN_SCRIPT_FILE_NAME")"
}
#########################################
#                                       #
#                                       #
#                                       #
#               /PREPARE                #
#                                       #
#                                       #
#                                       #
#########################################

#########################################
#                                       #
#                                       #
#                                       #
#               SIGNATURE               #
#                                       #
#                                       #
#                                       #
#########################################
# @type:        Orchestrator
# @description: Выполняет цикл GPG-верификации: импорт ключа, верификация
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка
install::verify_archive() {
    sig::gpg::import_public_key
    sig::gpg::verify_signature
}

# @type:        Source/Sink
# @description: Import embedded public GPG key into keyring
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - success
#               1 - import failed
sig::gpg::import_public_key() {
    gpg_signature_dir=$(mktemp -d --tmpdir "${UTIL_NAME}"-XXXXXX-signature) || return 1
    chmod 700 "$gpg_signature_dir"
    CLEANUP_COMMANDS+=("$gpg_signature_dir")

    local import_output
    import_output=$(printf '%s' "$GPG_PUBLIC_KEY_ASCII" | gpg --homedir "$gpg_signature_dir" --import 2>&1) || {
        log_error "$(_ "gpg.import_failed" "$import_output")"
        return 1
    }
    log_info "$(_ "gpg.imported" "$gpg_signature_dir")"
}

# @type:        Filter
# @description: Verify archive signature
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - valid signature
#               1 - invalid signature
sig::gpg::verify_signature() {
    local verify_output

    log_info "$(_ "gpg.verify_start")"

    verify_output=$(gpg --verify "$TMPSIGNATURE" "$TMPARCHIVE" 2>&1) || {
        log_error "$(_ "gpg.verify_failed")"
        log_info "$(_ "no_translate" "GPG verification output: $verify_output")"
        return 1
    }

    log_info "$(_ "gpg.verify_success")"
}
#########################################
#                                       #
#                                       #
#                                       #
#              /SIGNATURE               #
#                                       #
#                                       #
#                                       #
#########################################

#########################################
#                                       #
#                                       #
#                                       #
#                INSTALL                #
#                                       #
#                                       #
#                                       #
#########################################
# @type:        Orchestrator
# @description: Функция установки в систему
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка установки
install::to_system() {
    install::dir::create
    install::files::copy
    install::set_lang
    install::symlink::create
    install::set_permissions

    log_success "$(_ "install.complete")"
    log_info "$(_ "install.usage")"
}

# @type:        Orchestrator
# @description: Копирование файлов установки
# @params:
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка копирования
install::files::copy() {
    log_info "$(_ "files.copying" "$TEMP_PROJECT_DIR" "$INSTALL_DIR")"
    cp -av "${TEMP_PROJECT_DIR}"/* "${INSTALL_DIR}/" || return 1
}



# @type:        Sink
# @description: Запись/перезапись файла .lang (код без переноса строки)
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка записи файла
install::set_lang() {
    [[ -n "$INSTALLER_LANG" ]] && printf '%s' "$INSTALLER_LANG" > "$LANG_FILE"
}

# @type:        Orchestrator
# @description: Создание символической ссылки
# @params:
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка создания ссылки
install::symlink::create() {
    local main_script_path="$INSTALL_DIR/$MAIN_SCRIPT_FILE_NAME"

    ln -s "$main_script_path" "$SYMBOL_LINK_PATH" || return 1

    log_info "$(_ "symlink.created" "$main_script_path" "$(dirname "$SYMBOL_LINK_PATH")")"
    add_path_for_uninstall "$SYMBOL_LINK_PATH"
}

# @type:        Orchestrator
# @description: Установка прав на выполнение
# @params:
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
install::set_permissions() {
    log_info "$(_ "permissions.setting" "$INSTALL_DIR")"
    # chmod +x "$install_dir"/*.sh 2>/dev/null
    chmod a+rwx,o+t "$INSTALL_DIR" 2>/dev/null

}

# @type:        Sink
# @description: Обработчик прерывания INT
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
install::cleanup::int_handler() {
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        rc=130
        echo >&2
    fi
    log_info "$(_ "no_translate" "Сигнал прерывания/Interrupt signal [RC: $rc]")"
}

# @type:        Orchestrator
# @description: Очистка временных файлов при exit
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
install::cleanup() {
    local rc=$?

    if [ "$CLEANUP_DONE_FLAG" -eq 1 ]; then
        return 0
    fi

    log_info "$(_ "cleanup.start" "$rc")"

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
install::main() {
    log_info "$(_ "no_translate" "For logs type [journalctl -t bsss --since '10 minutes ago']")"
    init::ask_language
    log_info "$(_ "hello")"
    init::check_root
    init::check_dependencies
    install::dispatcher
}
#########################################
#                                       #
#                                       #
#                                       #
#               /INSTALL                #
#                                       #
#                                       #
#                                       #
#########################################

install::main
