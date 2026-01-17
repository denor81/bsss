#!/usr/bin/env bash
# ROLLBACK - Модуль отката настроек BSSS
# Использование: bash rollback.sh <rollback_type>
# Параметры:
#   rollback_type: ufw|full

set -Eeuo pipefail

readonly UTILS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"

source "${UTILS_DIR_PATH}/../lib/vars.conf"
source "${UTILS_DIR_PATH}/../lib/logging.sh"
source "${UTILS_DIR_PATH}/../modules/common-helpers.sh"
source "${UTILS_DIR_PATH}/../modules/04-ssh-port-helpers.sh"

ROLLBACK_TYPE=""

# @type:        Orchestrator
# @description: Откат UFW - деактивация и удаление правил BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::ufw_rollback() {
    log_warn "Инициирован откат UFW..."
    ufw::force_disable
    ufw::delete_all_bsss_rules
    # log_success "UFW ВЫКЛ"
}

# @type:        Orchestrator
# @description: Полная очистка системы от следов BSSS и деактивация UFW.
#               Вызывается при критическом сбое или таймауте.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::full_rollback() {
    log_warn "Инициирован полный демонтаж настроек ${UTIL_NAME^^}..."

    ssh::delete_all_bsss_rules
    ufw::force_disable
    ufw::delete_all_bsss_rules
    orchestrator::actions_after_port_change
    
    log_success "Система возвращена к исходному состоянию. Проверьте доступ по старым портам."
}

# @type:        Orchestrator
# @description: Выполняет откат в зависимости от типа операции
# @params:
#   rollback_type   Тип отката: ufw|full
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - неизвестный тип отката
orchestrator::execute_rollback() {
    ROLLBACK_TYPE="$1"

    # Валидация типа отката
    if [[ -z "$ROLLBACK_TYPE" ]]; then
        log_error "Не указан тип отката. Допустимые значения: ufw, full"
        return 1
    fi

    case "$ROLLBACK_TYPE" in
        ufw)
            orchestrator::ufw_rollback
            ;;
        full)
            orchestrator::full_rollback
            ;;
        *)
            log_error "Неизвестный тип отката: [$ROLLBACK_TYPE]. Допустимые значения: ufw, full"
            return 1
            ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа
# @params:      @ - параметры для execute_rollback
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка параметров
main() {
    orchestrator::execute_rollback "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi