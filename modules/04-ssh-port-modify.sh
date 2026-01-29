#!/usr/bin/env bash
# Изменяет SSH порт
# MODULE_TYPE: modify

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/common-helpers.sh"
source "${PROJECT_ROOT}/modules/04-ssh-port-helpers.sh"

trap common::exit::actions EXIT TERM INT
trap common::rollback::stop_script_by_rollback_timer SIGUSR1

# @type:        Orchestrator
# @description: Определяет состояние конфигурации SSH и переключает логику модуля на соответствующий сценарий
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки дочернего процесса
ssh::orchestrator::dispatch_logic() {
    # if sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK" | read -r -d '' _; then
    if sys::file::get_paths_by_mask "$SSH_CONFIGD_DIR" "$BSSS_SSH_CONFIG_FILE_MASK"; then
        ssh::orchestrator::config_exists_handler
    else
        ssh::orchestrator::config_not_exists_handler
    fi
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля изменения SSH порта
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка выполнения модулей
main() {
    log_start

    io::confirm_action "Изменить конфигурацию SSH порта?" # Вернет 0 или 2 при отказе (или 130 при ctrl+c)
    ssh::orchestrator::dispatch_logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
