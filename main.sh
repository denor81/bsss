#!/usr/bin/env bash
# Основной скрипт для последовательного запуска модулей системы
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
source "${PROJECT_ROOT}/modules/helpers/common.sh"

trap common::int::actions INT
trap common::exit::actions EXIT

# @type:        Filter
# @description: Парсинг параметров запуска с использованием getopts
# @params:
#   allowed_params [optional] Разрешенные параметры (default: $ALLOWED_PARAMS)
#   @            Остальные параметры для парсинга
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - некорректный параметр
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
# @description: Проверяет права доступа для запуска скрипта
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - права root есть
#               1 - недостаточно прав
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "$(_ "common.error_root_privileges")"
        return 1
    fi
}

# @type:        Sink
# @description: Выводит справочную информацию
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
show_help() {
    log_info "$(_ "common.info_short_params" "$ALLOWED_PARAMS" "$ALLOWED_PARAMS_HELP")"
}

# @type:        Orchestrator
# @description: Инициализирует систему логирования: создает директорию логов, создает файл и симлинк, настраивает права
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
log_dir_init() {
    local real_log="${PROJECT_ROOT}/${LOGS_DIR}/$(date +%Y-%m-%d_%H-%M-%S).log"
    
    # 1. Создаем дерево директорий
    mkdir -p "$(dirname "$real_log")"
    touch "$real_log"
    
    # 2. Создаем симлинк
    ln -sf "$real_log" "$CURRENT_LOG_SYMLINK"

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
# @description: Запуск модулей проверки в фиксированном порядке
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - все модули успешно выполнены
#               $? - код ошибки от модуля
runner::module::run_check() {
    local err=0

    log::draw_border
    bash "${PROJECT_ROOT}/${MODULES_DIR}/os-check.sh" || {
        main::process::exit_code $? "os-check.sh"
        err=1
    }
    bash "${PROJECT_ROOT}/${MODULES_DIR}/user-check.sh" || {
        main::process::exit_code $? "user-check.sh"
        err=1
    }
    bash "${PROJECT_ROOT}/${MODULES_DIR}/permissions-check.sh" || {
        main::process::exit_code $? "permissions-check.sh"
        err=1
    }
    bash "${PROJECT_ROOT}/${MODULES_DIR}/ssh-socket-check.sh" || {
        main::process::exit_code $? "ssh-socket-check.sh"
        err=1
    }
    bash "${PROJECT_ROOT}/${MODULES_DIR}/system-reload-check.sh" || {
        main::process::exit_code $? "system-reload-check.sh"
        err=1
    }
    bash "${PROJECT_ROOT}/${MODULES_DIR}/ssh-port-check.sh" || {
        main::process::exit_code $? "ssh-port-check.sh"
        err=1
    }
    bash "${PROJECT_ROOT}/${MODULES_DIR}/ufw-check.sh" || {
        main::process::exit_code $? "ufw-check.sh"
        err=1
    }
    (( err == 1 )) && { log_error "$(_ "common.error_module_error")"; log::draw_border; return 1; }
    log::draw_border
}

# @type:        Sink
# @description: Логирует статус завершения модуля
# @params:
#   exit_code   Код завершения модуля
#   module_tag  Имя модуля для логирования
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
main::process::exit_code() {
    local exit_code="${1:0}"
    local module_tag="${2:-}"

    (( exit_code == 0 )) && { log_info "$(_ "common.info_module_successful" "$exit_code" "$module_tag")"; return 0; }

    case "$exit_code" in
        2|130) log_info "$(_ "common.info_module_user_cancelled" "$exit_code" "$module_tag")" ;;
        3) log_warn "$(_ "common.info_module_rollback" "$exit_code" "$module_tag")" ;;
        4) log_warn "$(_ "common.info_module_requires" "$exit_code" "$module_tag")" ;;
        *) log_error "$(_ "common.unexpected_error_module_failed_code" "$exit_code" "$module_tag")" ;;
    esac
}

# @type:        Orchestrator
# @description: Стандартное меню модулей изменения в циклическом режиме
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - модули выполнены успешно
#               $? - проброс кода ошибки от модуля
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
        menu_id=$(io::ask_value "$(_ "io.ask_value.select_module")" "" "([0-7]|0[0-1])" "0-7" "0" | tr -d '\0')

        case "$menu_id" in
            0) return 0 ;;
            00) runner::module::run_check ;;
            01) i18n::installer::lang_setup && i18n::load ;;
            1) bash "${PROJECT_ROOT}/${MODULES_DIR}/auto-setup.sh" || main::process::exit_code $? "auto-setup.sh" ;;
            2) bash "${PROJECT_ROOT}/${MODULES_DIR}/system-update.sh" || main::process::exit_code $? "system-update.sh" ;;
            3) bash "${PROJECT_ROOT}/${MODULES_DIR}/ssh-port-modify.sh" || main::process::exit_code $? "ssh-port-modify.sh" ;;
            4) bash "${PROJECT_ROOT}/${MODULES_DIR}/ufw-modify.sh" || main::process::exit_code $? "ufw-modify.sh" ;;
            5) bash "${PROJECT_ROOT}/${MODULES_DIR}/user-modify.sh" || main::process::exit_code $? "user-modify.sh" ;;
            6) bash "${PROJECT_ROOT}/${MODULES_DIR}/permissions-modify.sh" || main::process::exit_code $? "permissions-modify.sh" ;;
            7) bash "${PROJECT_ROOT}/${MODULES_DIR}/full-rollback-modify.sh" || main::process::exit_code $? "full-rollback-modify.sh" ;;
        esac
    done
}

# @type:        Orchestrator
# @description: Основная функция запуска: проверяет зависимости, запускает проверку и меню модификации
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка проверки
#               $? - код ошибки от модуля
run() {
    sys::gawk::check_dependency
    sys::log::rotate_old_files

    runner::module::run_check
    runner::module::run_modify
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:
#   @           Параметры командной строки для передачи в parse_params
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка проверки прав или параметров
#               $? - ошибка выполнения действия
main() {
    log_dir_init
    log_start
    check_permissions
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
