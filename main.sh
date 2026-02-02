#!/usr/bin/env bash
# Основной скрипт для последовательного запуска модулей системы
# Usage: run with ./main.sh [options] [-h|-u]

set -Eeuo pipefail

# Константы
readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly ALLOWED_PARAMS="hu"
readonly ALLOWED_PARAMS_HELP="[-h помощь | -u удаление]"
PARAMS_ACTION=""

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/lib/uninstall_functions.sh"
source "${PROJECT_ROOT}/modules/helpers/init.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"

trap 'exit 100' INT
trap log_stop EXIT

# @type:        Filter
# @description: Проверяет права доступа для запуска скрипта
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - права root есть
#               1 - недостаточно прав
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Требуются права root или запуск через 'sudo'. Запущен как обычный пользователь."
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
    log_info "Доступны короткие параметры $ALLOWED_PARAMS $ALLOWED_PARAMS_HELP"
}

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
    # Всегда используем дефолтный ALLOWED_PARAMS
    local allowed_params="${1:-$ALLOWED_PARAMS}"
    shift
    
    while getopts ":$allowed_params" opt "$@"; do
        case "${opt}" in
            h)  ACTION="help" ;;
            u)  ACTION="uninstall" ;;
            \?) log_error "Некорректный параметр -$OPTARG, доступны: $allowed_params"; return 1 ;;
            :)  log_error "Параметр -$OPTARG требует значение"; return 1 ;;
        esac
    done
}

log_init() {
    local real_log="${PROJECT_ROOT}/${LOGS_DIR}/$(date +%Y-%m-%d_%H-%M-%S).log"
    
    mkdir -p "$(dirname "$real_log")"
    touch "$real_log"
    
    # Создаем симлинк на текущий лог-файл
    ln -sf "$real_log" "$CURRENT_LOG_SYMLINK"
}

# log_init() {
#     # Logging initialization
#     mkdir -p "${PROJECT_ROOT}/${LOGS_DIR}"
#     readonly LOG_FILE="${PROJECT_ROOT}/${LOGS_DIR}/$(date +%Y-%m-%d_%H-%M-%S).log"
#     exec > >(tee -a "$LOG_FILE") 2>&1
# }

# @type:        Orchestrator
# @description: Поиск и запуск модулей с типом 'check'
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - модули найдены и все успешно выполнены
#               1 - в случае отсутствия модулей
#               2 - в случае ошибки одного из модулей
#               5 - отсутствуют обязательные метатеги MODULE_ORDER
runner::module::run_check() {
    local err=0
    local found=0

    log::draw_border
    while read -r -d '' m_path <&3; do
        found=$((found + 1))
        if ! bash "$m_path"; then
            err=1
        fi
    done 3< <(sys::file::get_paths_by_mask "${PROJECT_ROOT}/$MODULES_DIR" "$MODULES_MASK" \
    | sys::module::get_paths_w_type \
    | sys::module::get_by_type "$MODULE_TYPE_CHECK" \
    | sys::module::sort_by_order)

    (( found == 0 )) && { log_error "Запуск не возможен, Модули не найдены"; log::draw_border; return 1; }
    (( err )) && { log_error "Запуск не возможен, один из модулей показывает ошибку"; log::draw_border; return 2; }
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
#               пусто - если выбран выход (0)
# @exit_code:   0 - успешно
#               1 - нет доступных модулей
runner::module::select_modify() {
    local -a module_paths=()
    local module_name

    # Читаем все пути в массив через NUL-разделитель
    mapfile -d '' -t module_paths

    # Проверяем, есть ли модули
    if (( ${#module_paths[@]} == 0 )); then
        log_error "Нет доступных модулей для настройки"
        return 1
    fi

    # Отображаем меню
    log_info "Доступные модули настройки:"
    local i
    for ((i = 0; i < ${#module_paths[@]}; i++)); do
        module_name=$(basename "${module_paths[$i]}")
        log_info_simple_tab "$((i + 1)). $module_name"
    done
    log_info_simple_tab "0. Выход"
    log_info_simple_tab "00. Проверка системы (check)"

    # Запрашиваем выбор пользователя
    local selection
    read -r -d '' selection < <(io::ask_value "Выберите модуль" "" "^(00|[0-$(( ${#module_paths[@]} ))])$" "0-${#module_paths[@]}")
    
    case "$selection" in
        0) log_info "Выход из меню настройки"; printf '%s\0' "EXIT" ;; # Возвращаем маркер EXIT
        00) printf '%s\0' "CHECK" ;; # Возвращаем маркер CHECK
        *)  printf '%s\0' "${module_paths[$((selection - 1))]}" ;; # Возвращаем выбранный путь
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
        local exit_code=0
        local selected_module

        # Получаем выбранный модуль через пайплайн
        read -r -d '' selected_module < <(sys::file::get_paths_by_mask "${PROJECT_ROOT}/$MODULES_DIR" "$MODULES_MASK" \
            | sys::module::get_paths_w_type \
            | sys::module::get_by_type "$MODULE_TYPE_MODIFY" \
            | sys::module::sort_by_order \
            | runner::module::select_modify) || return

        # Обработка главного меню
        if [[ "$selected_module" == "CHECK" ]]; then
            runner::module::run_check
        elif [[ "$selected_module" == "EXIT" ]]; then
            break
        fi 

        # Обработка результата выполнения модуля
        if [[ -f "$selected_module" ]]; then
            bash "$selected_module" || exit_code=$?

            case "$exit_code" in
                0) log_info "Модуль успешно завершен [Code: $exit_code]" ;;
                2|130) log_info "Модуль завершен пользователем [Code: $exit_code]" ;;
                3) log_info "Модуль завершен откатом [Code: $exit_code]" ;;
                4) log_info "Модуль требует предварительной настройки SSH [Code: $exit_code]" ;;
                5) log_error "Отсутствуют обязательные метатеги MODULE_ORDER [Code: $exit_code]" ;;
                *) log_error "Ошибка в модуле [$selected_module] [Code: $exit_code]" ;;
            esac
        fi
    done
}

run() {
    sys::gawk::check_dependency
    sys::module::validate_order
    sys::module::check_duplicate_order
    # sys::log::rotate_old_files

    runner::module::run_check
    io::confirm_action "Запустить настройку?" # Вернет 0 или 2 при отказе (или 130 при ctrl+c)
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
    log_init
    log_start
    check_permissions
    parse_params "$ALLOWED_PARAMS" "$@"

    case "$PARAMS_ACTION" in
        help)      show_help ;;
        uninstall) run_uninstall ;;
        *)         run ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
