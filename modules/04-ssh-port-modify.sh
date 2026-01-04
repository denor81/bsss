#!/usr/bin/env bash
# Изменяет SSH порт
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly MODULES_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${MODULES_DIR_PATH}/../lib/vars.conf"
source "${MODULES_DIR_PATH}/../lib/logging.sh"
source "${MODULES_DIR_PATH}/../lib/user_confirmation.sh"
source "${MODULES_DIR_PATH}/common-helpers.sh"
source "${MODULES_DIR_PATH}/04-ssh-port-helpers.sh"

# @type:        Dispatcher
# @description: Определяет состояние конфигурации SSH (существует/отсутствует) 
#               и переключает логику модуля на соответствующий сценарий.
# @params:      Использует глобальные SSH_CONFIGD_DIR и BSSS_SSH_CONFIG_FILE_MASK.
# @stdin:       Не используется.
# @stdout:      Зависит от вызываемых функций (bsss_config_not_exists / bsss_config_exists).
# @stderr:      Диагностика процесса поиска файлов.
# @exit_code:   0 — логика успешно отработала; 1+ — если в дочерних сценариях произошел сбой.
dispatch_logic() {
    local paths=()
    mapfile -t -d '' paths < <(get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK")

    if (( ${#paths[@]} == 0 )); then
        # Сценарий A: Конфигурация не найдена
        bsss_config_not_exists
    else
        # Сценарий B: Конфигурация найдена, передаем список файлов аргументами
        bsss_config_exists "${paths[@]}"
    fi
}

# @type:        Dispatcher
# @description: Обработчик сценария отсутствия конфигурации SSH.
#               Запускает установку порта в режиме "только создание".
# @params:      Не принимает параметры.
# @stdin:       Не используется.
# @stdout:      Зависит от вызываемой функции action_restore_and_install_new_port.
# @stderr:      Зависит от вызываемой функции action_restore_and_install_new_port.
# @exit_code:   0 — логика успешно отработала; 1+ — если в дочерних функциях произошел сбой.
bsss_config_not_exists() {
    action_restore_and_install_new_port
    actions_after_port_install
}

# @type:        Dispatcher
# @description: Интерфейс выбора действий при наличии существующих конфигов.
# @params:      Список путей к файлам.
# @stdin:       Не используется.
# @stdout:      Текстовый лог в stderr (логи).
# @stderr:      Текстовый лог в stderr (логи).
# @exit_code:   0 — логика успешно отработала; 1+ — если в дочерних функциях произошел сбой.
bsss_config_exists() {
    show_bsss_configs "$@"

    log_info_simple_tab "1. Сброс (удаление правила ${UTIL_NAME^^})"
    log_info_simple_tab "2. Переустановка (замена на новый порт)"

    local user_action
    user_action=$(ask_value "Выберите" "" "^[12]$" "1/2") || return

    case "$user_action" in
        1) action_restore_default "$@" ;;
        2) action_restore_and_install_new_port "$@" ;;
    esac
    actions_after_port_install
}

main() {
    dispatch_logic
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
