#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Usage: run with ./main.sh [options] [-h|-u]

set -Eeuo pipefail

# Константы
readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly ALLOWED_PARAMS="hul:"
readonly ALLOWED_PARAMS_HELP="[-h помощь | -u удаление | -l [ru|en] язык]"
PARAMS_ACTION=""
PARAMS_LANG=""

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/i18n/language_installer.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/lib/uninstall_functions.sh"
source "${PROJECT_ROOT}/modules/helpers/init.sh"
source "${PROJECT_ROOT}/modules/helpers/os-check.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"

# Что бы не путать наши логи и ошибки bash
# Наши логи пишутся в 3-й дескриптор
# Ошибки bash во 2-й дескриптор
# Привязали 3-й дескриптор к терминалу
exec 3>&2

# ПЕРЕХВАТЧИК ОШИБОК BASH
# Отвязали 2-й дескриптор от терминала
# Это позволяет ловить исключительно ошибки bash
exec 2> >(while read -r line; do 
    log::bash::error "$line"
done)

trap common::int::actions INT
trap common::exit::actions EXIT

# @type:        Orchestrator
# @description: Парсит параметры CLI и устанавливает глобальные переменные PARAMS_ACTION/PARAMS_LANG
# @params:      args Аргументы командной строки (array\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               1 критическая ошибка
parse_params() {
    OPTIND=1

    while getopts ":$ALLOWED_PARAMS" opt "$@"; do
        case "${opt}" in
            h)  PARAMS_ACTION="help" ;;
            u)  PARAMS_ACTION="uninstall" ;;
            l)  PARAMS_LANG="$OPTARG" ;;
            \?) log_error "$(_ "no_translate" "Invalid parameter -$OPTARG, available: $ALLOWED_PARAMS")"; return 1 ;;
            :)  log_error "$(_ "no_translate" "Parameter -$OPTARG requires a value")"; return 1 ;;
        esac
    done
}

# @type:        Validator
# @description: Проверяет права root для запуска скрипта
#               Проверка выполняется до инициализации системы логирования
#               по этому пишем напрямую в 3-й дескриптор, котрый связан с терминалом
#               (никаких логов по этой ошибке не будет - только лог в терминал)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               1 критическая ошибка
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "$(_ "common.error_root_privileges")"
        return 1
    fi
}

# @type:        Sink
# @description: Выводит справочную информацию по параметрам
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
show_help() {
    log_info "$(_ "common.info_short_params" "$ALLOWED_PARAMS" "$ALLOWED_PARAMS_HELP")"
}

# @type:        Orchestrator
# @description: Инициализирует систему логирования: создает директорию логов, файл, симлинк и настраивает права
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
log_dir_init() {
    local real_log="${PROJECT_ROOT}/${LOGS_DIR}/$(date +%Y-%m-%d_%H-%M-%S).log"
    
    # 1. Создаем дерево директорий
    mkdir -p "$(dirname "$real_log")"
    touch "$real_log"
    
    # 2. Создаем симлинк
    ln -sf "$real_log" "$CURRENT_LOG_SYMLINK"

    local log_header="\
# ==============================================================================
# WARNING: This log file may contain incomplete data.
# In the event of an abnormal termination (e.g., Ctrl+C or script crash),
# logs from the '/utils/rollback.sh' process may be lost due to the closure of 
# the FIFO pipe used for terminal streaming.
#
# Under normal conditions, logs are consistent across all channels.
#
# If the script was interrupted and you need full rollback logs, please 
# refer to the system journal using the following command:
# journalctl -t bsss --since \"10 minutes ago\"
# =============================================================================="

    { echo "$log_header" >> "$CURRENT_LOG_SYMLINK"; } 2>/dev/null || true

    # 3. Определяем, кому отдавать права
    # Если запущен через sudo, берем реального юзера, иначе текущего
    local target_user="${SUDO_USER:-$USER}"
    
    # 4. Меняем владельца рекурсивно на всю папку логов
    # Это покроет и файлы, и сам симлинк (включая тот, на что он указывает)
    chown -R "$target_user:$target_user" "${PROJECT_ROOT}/${LOGS_DIR}"
    
    # 5. Отдельно фиксируем права на сам симлинк (флаг -h)
    chown -h "$target_user:$target_user" "$CURRENT_LOG_SYMLINK"
}

# @type:        Orchestrator
# @description: Запускает модули проверки в фиксированном порядке
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               1 критическая ошибка
runner::module::run_check() {
    local err=0
    local dir="${PROJECT_ROOT}/${MODULES_DIR}"

    log::draw_border
    bash "${dir}/os-check.sh" || err=1
    bash "${dir}/ssh-socket-check.sh" || err=1
    bash "${dir}/system-reload-check.sh" || err=1
    bash "${dir}/user-check.sh" || err=1
    bash "${dir}/ssh-port-check.sh" || err=1
    bash "${dir}/permissions-check.sh" || err=1
    bash "${dir}/ufw-check.sh" || err=1
    (( err == 1 )) && { log_error "$(_ "common.error_module_error")"; log::draw_border; return 1; }
    log::draw_border
}

# @type:        Sink
# @description: Логирует статус завершения модуля по коду возврата
# @params:      exit_code Код завершения модуля (num\0)
#               module_tag Тег модуля для логирования (string\0)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
main::process::exit_code() {
    local exit_code="${1:0}"
    local module_tag="${2:-}"

    # (( exit_code == 0 )) && { log_info "$(_ "common.info_module_successful" "$exit_code" "$module_tag")"; return 0; }

    case "$exit_code" in
        0) log_info "$(_ "common.info_module_successful" "$exit_code" "$module_tag")" ;;
        2|130) log_info "$(_ "common.info_module_user_cancelled" "$exit_code" "$module_tag")" ;;
        3) log_warn "$(_ "common.info_module_rollback" "$exit_code" "$module_tag")" ;;
        4) log_warn "$(_ "common.info_module_requires" "$exit_code" "$module_tag")" ;;
        *) log_error "$(_ "common.unexpected_error_module_failed_code" "$exit_code" "$module_tag")" ;;
    esac
}

# @type:        Orchestrator
# @description: Запускает интерактивное меню модулей изменения в циклическом режиме
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               $? код ошибки от модуля
runner::module::run_modify() {
    while true; do
        log_info "$(_ "common.menu_header")"
        log_info_simple_tab "1. $(_ "module.auto.setup.name")"
        log_info_simple_tab "2. $(_ "module.system.update.name")"
        log_info_simple_tab "3. $(_ "module.ssh.name")"
        log_info_simple_tab "4. $(_ "module.ufw.name")"
        log_info_simple_tab "5. $(_ "module.user.create.name")"
        log_info_simple_tab "6. $(_ "module.permissions.modify.name")"
        log_info_simple_tab "7. $(_ "module.full_rollback.name")"
        log_info_simple_tab "0. $(_ "common.exit")"
        log_info_simple_tab "00. $(_ "common.menu_check")"
        log_info_simple_tab "01. $(_ "common.menu_language")"

        local menu_id
        menu_id=$(io::ask_value "$(_ "io.ask_value.select_module")" "" "^([0-7]|0[0-1])$" "0-7" "^0$" | tr -d '\0')

        local rc=0
        local tag
        local dir="${PROJECT_ROOT}/${MODULES_DIR}"
        case "$menu_id" in
            0) return 0 ;;
            00) tag="check"; runner::module::run_check ;;
            01) tag="lang_change"; i18n::installer::lang_setup && i18n::load ;;
            1) tag="auto-setup.sh"; bash "${dir}/${tag}" || rc=$? ;;
            2) tag="system-update.sh"; bash "${dir}/${tag}" || rc=$? ;;
            3) tag="ssh-port-modify.sh"; bash "${dir}/${tag}" || rc=$? ;;
            4) tag="ufw-modify.sh"; bash "${dir}/${tag}" || rc=$? ;;
            5) tag="user-modify.sh"; bash "${dir}/${tag}" || rc=$? ;;
            6) tag="permissions-modify.sh"; bash "${dir}/${tag}" || rc=$? ;;
            7) tag="full-rollback-modify.sh"; bash "${dir}/${tag}" || rc=$? ;;
        esac
        main::process::exit_code "$rc" "$tag"
    done
}

# @type:        Orchestrator
# @description: Основная функция запуска: проверяет зависимости, запускает проверку и меню модификации
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               1 критическая ошибка
#               $? код ошибки от модуля
run() {
    log_info "$(_ "init.bsss.full_name")"

    log_info "$(_ "init.critical.dependencies")"
    sys::id_and_ver_check
    sys::gawk::check_dependency

    sys::log::rotate_old_files

    runner::module::run_check
    runner::module::run_modify
}

# @type:        Orchestrator
# @description: Основная точка входа: инициализация, проверка прав, парсинг параметров и диспетчеризация
# @params:      args Аргументы командной строки (array\n)
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успех
#               1 критическая ошибка
#               $? код ошибки выполнения
main() {
    check_permissions
    log_dir_init
    log_start
    parse_params "$@"

    i18n::installer::dispatcher "$PARAMS_LANG"

    case "$PARAMS_ACTION" in
        help)      show_help ;;
        uninstall) run_uninstall ;;
        *)         run ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
