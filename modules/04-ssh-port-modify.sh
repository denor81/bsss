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
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @stderr:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
orchestrator::dispatch_logic() {

    if [[ -z "$(sys::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | tr -d '\0')" ]]; then
        log_info "Активных правил ${UTIL_NAME^^} для SSH не обнаружено, синхронизация не требуется."
        orchestrator::bsss_config_not_exists
    else
        orchestrator::bsss_config_exists
    fi
}

# @type:        Caller
# @description: Обработчик сценария отсутствия конфигурации SSH
#               Установка порта
#               Завершающие команды после установки порта
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @stderr:      нет
# @exit_code:   0 — упешно
#               $? — код ошибки дочернего процесса
orchestrator::bsss_config_not_exists() {
    ssh::ask_new_port | ssh::reset_and_pass | ufw::reset_and_pass | ssh::install_new_port
    orchestrator::actions_after_port_install
}

# @type:        Dispatcher
# @description: Интерфейс выбора действий при наличии существующих конфигов.
# @params:      Список путей к файлам.
# @stdin:       Не используется.
# @stdout:      Текстовый лог в stderr (логи).
# @stderr:      Текстовый лог в stderr (логи).
# @exit_code:   0 — логика успешно отработала; 1+ — если в дочерних функциях произошел сбой.
orchestrator::bsss_config_exists() {
    ssh::show_bsss_configs

    log_info_simple_tab "1. Сброс (удаление правила ${UTIL_NAME^^})"
    log_info_simple_tab "2. Переустановка (замена на новый порт)"

    local user_action
    user_action=$(io::ask_value "Выберите" "" "^[12]$" "1/2") || return

    case "$user_action" in
        1) ssh::reset_and_pass | ufw::reset_and_pass ;;
        2) ssh::ask_new_port | ssh::reset_and_pass | ufw::reset_and_pass | ssh::install_new_port ;;
    esac
    orchestrator::actions_after_port_install
}

main() {
    orchestrator::dispatch_logic
}

# (Guard): Выполнять main ТОЛЬКО если скрипт запущен, а не импортирован
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
