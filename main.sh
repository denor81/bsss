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

# @type:        Filter
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
# @description: Поиск и запуск модулей с типом 'check'
#               Используется дескриптор 3 что бы не забивать стандартные 1 и 2
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - модули найдены и все успешно выполнены
#               1 - в случае отсутствия модулей
#               2 - в случае ошибки одного из модулей
#               5 - отсутствуют обязательные метатеги MODULE_ORDER
runner::module::run_check() {
    local err=0
    local founded_modules=0

    log::draw_border
    while read -r -d '' m_path <&3; do
        founded_modules=$((founded_modules + 1))
        bash "$m_path" || {
            main::process::exit_code $? "$(basename $m_path)"
            err=1
        }
    done 3< <(sys::file::get_paths_by_mask "${PROJECT_ROOT}/$MODULES_DIR" "$MODULES_MASK" \
    | sys::module::get_paths_w_type \
    | sys::module::get_by_type "$MODULE_TYPE_CHECK" \
    | sys::module::sort_by_order)

    (( founded_modules == 0 )) && { log_error "$(_ "common.error_no_modules_found")"; log::draw_border; return 1; }
    (( err == 1 )) && { log_error "$(_ "common.error_module_error")"; log::draw_border; return 1; }
    log::draw_border
}

# Примечание: Используем массив для хранения путей между отображением и выбором.
# В чистом pipe-first стиле это невозможно без временных файлов или глобальных переменных.
# Для интерактивных меню это технически оправданное исключение.
# @type:        Filter
# @description: Отображает нумерованное меню модулей для выбора
# @params:      нет
# @stdin:       path\0 (0..N) - пути к модулям modify
# @stdout:      path\0 (0..1) - выбранный путь к модулю
#               CHECK\0 - если выбрана проверка системы (00)
#               EXIT\0 - если выбран выход (0)
# @exit_code:   0 - успешно
#               1 - нет доступных модулей
runner::module::select_modify() {
    local -a module_paths=()
    local module_name

    # Читаем все пути в массив через NUL-разделитель
    mapfile -d '' -t module_paths

    # Проверяем, есть ли модули
    if (( ${#module_paths[@]} == 0 )); then
        log_error "$(_ "common.error_no_modules_available")"
        return 1
    fi

    # Отображаем меню
    log_info "$(_ "common.menu_header")"
    local i
    for ((i = 0; i < ${#module_paths[@]}; i++)); do
        module_name=$(gawk '
            BEGIN { name="" }
            /^# MODULE_NAME:/ {
                sub(/^# MODULE_NAME:[[:space:]]*/, "")
                name=$0
                exit
            }
            /^[^#]/ { exit }
            END {
                if (name=="") name=FILENAME
                sub(/.*\//, "", name)
                print name
            }
        ' "${module_paths[$i]}")
        log_info_simple_tab "$(_ "common.info_menu_item_format" "$((i + 1))" "$(_ "$module_name")")"
    done

    local max_id="${#module_paths[@]}"
    local menu_exit="0"
    local menu_check="00"
    local menu_lang="01"
    
    log_info_simple_tab "$(_ "common.exit" "$menu_exit")"
    log_info_simple_tab "$(_ "common.menu_check" "$menu_check")"
    log_info_simple_tab "$(_ "common.menu_language" "$menu_lang")"

    # Запрашиваем выбор пользователя
    local selection
    selection=$(io::ask_value "$(_ "io.ask_value.select_module")" "" "^($menu_check|$menu_lang|[$menu_exit-$max_id])$" "$menu_exit-$max_id" "$menu_exit" | tr -d '\0') || return
    case "$selection" in
        "$menu_check")  printf '%s\0' "CHECK" ;; # Возвращаем маркер CHECK
        "$menu_lang")   printf '%s\0' "LANG_CHANGE" ;; # Возвращаем маркер смены языка
        *)              printf '%s\0' "${module_paths[$((selection - 1))]}" ;; # Возвращаем выбранный путь
    esac
}

runner::module::execute_modify() {
    local exit_code=0
    local selected_module

    # При прерывании предыдущего пайпа - сюда ничего не придет и read упадет с ошибкой и переменная selected_module будет пустая
    # что приведет к срабатыванию последнего элемента лога в блоке case - по этому гасим этот случай return 0
    read -r -d '' selected_module || { [[ -z "$selected_module" ]] && return 0; }

    if [[ "$selected_module" == "CHECK" ]]; then

        runner::module::run_check || exit_code=$?

    elif [[ "$selected_module" == "LANG_CHANGE" ]]; then

        # Бросаем маркер из текущего пайпа наверх, что бы загрузить язык в главном процессе
        i18n::installer::lang_setup && echo "RELOAD_I18N" || exit_code=$?

    elif [[ -f "$selected_module" ]]; then

        bash "$selected_module" || exit_code=$?

    else

        exit_code=1

    fi
    main::process::exit_code "$exit_code" "$(basename $selected_module)"
}

main::process::exit_code() {
    local exit_code="${1:0}"
    local module_tag="${2:-}"

    (( exit_code == 0 )) && { log_info "$(_ "common.info_module_successful" "$exit_code" "$module_tag")"; return 0; }

    case "$exit_code" in
        2|130) log_info "$(_ "common.info_module_user_cancelled" "$exit_code" "$module_tag")" ;;
        3) log_warn "$(_ "common.info_module_rollback" "$exit_code" "$module_tag")" ;;
        4) log_warn "$(_ "common.info_module_requires" "$exit_code" "$module_tag")" ;;
        5) log_error "$(_ "common.error_missing_meta_tags" "$exit_code" "$module_tag")" ;;
        *) log_error "$(_ "common.unexpected_error_module_failed_code" "$exit_code" "$module_tag")" ;;
    esac
}

# @type:        Orchestrator
# @description: Поиск и запуск модулей с типом 'modify' в циклическом меню
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - модули найдены и все успешно выполнены
#               $? - проброс кода ошибки от модуля
runner::module::run_modify() {
    while true; do
        local res=""
        res=$(sys::file::get_paths_by_mask "${PROJECT_ROOT}/$MODULES_DIR" "$MODULES_MASK" \
            | sys::module::get_paths_w_type \
            | sys::module::get_by_type "$MODULE_TYPE_MODIFY" \
            | sys::module::sort_by_order \
            | runner::module::select_modify \
            | runner::module::execute_modify) \
            || { common::pipefail::fallback "${PIPESTATUS[@]}"; }
            
        [[ "$res" == "RELOAD_I18N" ]] && i18n::load # Загружаем язык в главном процессе
    done
}

# @type:        Orchestrator
# @description: Основная функция запуска: проверяет зависимости, запускает проверку и меню модификации
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка проверки или запуска модулей
run() {
    sys::gawk::check_dependency
    sys::module::validate_order
    sys::module::check_duplicate_order
    sys::log::rotate_old_files

    runner::module::run_check
    # io::confirm_action "$(_ "io.confirm_action.run_setup")" # Вернет 0 или 2 при отказе (или 130 при ctrl+c)
    runner::module::run_modify
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      @ - параметры командной строки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка проверки прав или параметров
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
