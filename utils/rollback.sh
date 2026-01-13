#!/usr/bin/env bash
# ROLLBACK

set -Eeuo pipefail

readonly UTILS_DIR_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"
readonly MAIN_SCRIPT_PID="$1"

source "${UTILS_DIR_PATH}/../lib/vars.conf"
source "${UTILS_DIR_PATH}/../lib/logging.sh"
source "${UTILS_DIR_PATH}/../lib/user_confirmation.sh"
source "${UTILS_DIR_PATH}/../modules/common-helpers.sh"
source "${UTILS_DIR_PATH}/../modules/04-ssh-port-helpers.sh"

trap 'orchestrator::stop_rollback' SIGUSR1

orchestrator::stop_rollback() {
    log_info "Watchdog остановлен"
    exit 0
}

orchestrator::watchdog_timer() {
    разобраться со sleep - блокирует trap
    sleep "$ROLLBACK_TIMER_SECONDS"
    log_info "Останавливаем главный процесс $MAIN_SCRIPT_PID"
    kill -USR1 "$MAIN_SCRIPT_PID" 2>/dev/null || true
    wait "$MAIN_SCRIPT_PID" 2>/dev/null || true
    log_info "Главный процесс остановлен $MAIN_SCRIPT_PID"
    orchestrator::total_rollback
}

# @type:        Orchestrator
# @description: Полная очистка системы от следов BSSS и деактивация UFW.
#               Вызывается при критическом сбое или таймауте.
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - всегда
orchestrator::total_rollback() {
    log_warn "ROLLBACK: Инициирован полный демонтаж настроек BSSS..."

    ssh::delete_all_bsss_rules
    ufw::force_disable
    ufw::delete_all_bsss_rules
    orchestrator::actions_after_port_change
    
    log_success "ROLLBACK: Система возвращена к исходному состоянию. Проверьте доступ по старым портам."
    printf "EOF\n"
}

main() {
    orchestrator::watchdog_timer
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi