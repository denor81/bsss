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

# @type:        Orchestrator
# @description: Определяет состояние конфигурации SSH (существует/отсутствует) 
#               и переключает логику модуля на соответствующий сценарий.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
orchestrator::dispatch_logic() {

    if sys::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | read -r -d '' _; then
        orchestrator::bsss_config_exists
    else
        orchestrator::bsss_config_not_exists
    fi
}

# @type:        Orchestrator
# @description: Обработчик сценария отсутствия конфигурации SSH
#               Установка нового порта SSH и добавление правила в UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 — упешно
#               $? — код ошибки дочернего процесса
orchestrator::bsss_config_not_exists() {
    ssh::ask_new_port | ssh::reset_and_pass | ufw::reset_and_pass | ssh::install_new_port
    orchestrator::actions_after_port_install
}

# @type:        Orchestrator
# @description: Интерфейс выбора действий при наличии существующих конфигов
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки дочернего процесса
orchestrator::bsss_config_exists() {
    ssh::log_bsss_configs

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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
