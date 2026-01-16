#!/usr/bin/env bash
# Основной скрипт для последовательного запуска модулей системы
# Usage: run with ./local-runner.sh

set -Eeuo pipefail

# Константы
readonly MAIN_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MAIN_DIR_PATH}/lib/vars.conf"
source "${MAIN_DIR_PATH}/lib/logging.sh"
source "${MAIN_DIR_PATH}/lib/user_confirmation.sh"
source "${MAIN_DIR_PATH}/modules/common-helpers.sh"

# @type:        Orchestrator
# @description: Поиск и запуск модулей с типом 'check'
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - модули найдены и все успешно выполнены
#               1 - в случае отсутствия модулей
#               2 - в случае ошибки одного из модулей
run_modules_polling() {
    local err=0
    local found=0

    log::draw_border
    while read -r -d '' m_path <&3; do
        found=$((found + 1))
        if ! bash "$m_path"; then
            err=1
        fi
    done 3< <(sys::get_paths_by_mask "${MAIN_DIR_PATH%/}/$MODULES_DIR" "$MODULES_MASK" \
    | sys::get_modules_paths_w_type \
    | sys::get_modules_by_type "$MODULE_TYPE_CHECK")

    (( found == 0 )) && { log_error "Запуск не возможен, Модули не найдены"; log::draw_border; return 1; }
    (( err > 0 )) && { log_error "Запуск не возможен, один из модулей показывает ошибку"; log::draw_border; return 2; }
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
orchestrator::select_modify_module() {
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
    log::draw_lite_border
    log_info "Доступные модули настройки:"
    local i
    for ((i = 0; i < ${#module_paths[@]}; i++)); do
        module_name=$(basename "${module_paths[$i]}")
        log_info_simple_tab "$((i + 1)). $module_name"
    done
    log_info_simple_tab "0. Выход"
    log_info_simple_tab "00. Проверка системы (check)"
    log::draw_lite_border

    # Запрашиваем выбор пользователя
    local selection
    selection=$(io::ask_value "Выберите модуль" "" "^(00|[0-$(( ${#module_paths[@]} ))])$" "0-${#module_paths[@]}" | tr -d '\0')

    if [[ "$selection" == "0" ]]; then
        log_info "Выход из меню настройки"
        printf '%s\0' "EXIT"
        return 0
    elif [[ "$selection" == "00" ]]; then
        printf '%s\0' "CHECK"
        return 0
    fi

    # Выводим выбранный путь
    printf '%s\0' "${module_paths[$((selection - 1))]}"
}

# @type:        Orchestrator
# @description: Поиск и запуск модулей с типом 'modify' в циклическом меню
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - модули найдены и все успешно выполнены
#               $? - проброс кода ошибки от модуля
run_modules_modify() {
    while true; do
        local selected_module

        # Получаем выбранный модуль через пайплайн
        selected_module=$(sys::get_paths_by_mask "${MAIN_DIR_PATH%/}/$MODULES_DIR" "$MODULES_MASK" \
            | sys::get_modules_paths_w_type \
            | sys::get_modules_by_type "$MODULE_TYPE_MODIFY" \
            | orchestrator::select_modify_module | tr -d '\0') || return

        # Обработка выбора пользователя
        if [[ "$selected_module" == "CHECK" ]]; then
            run_modules_polling
        elif [[ "$selected_module" == "EXIT" ]]; then
            break
        elif [[ -n "$selected_module" ]]; then
            bash "$selected_module" && exit_code=0 || exit_code=$?

            case "$exit_code" in
                0)
                    # Успешное завершение
                    ;;
                2)
                    # Наш специфический код: отмена пользователем
                    log_info "Модуль завершен пользователем (Skip)"
                    ;;
                *)
                    # Все остальные коды считаем критической ошибкой
                    log_error "Ошибка в модуле [$selected_module] (Exit code: $exit_code)"
                    ;;
            esac
        fi
    done
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка выполнения модулей
main() {
    run_modules_polling
    io::confirm_action "Запустить настройку?"
    run_modules_modify
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
