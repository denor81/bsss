#!/usr/bin/env bash
# Проверяет SSH порт
# MODULE_TYPE: check



set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
readonly CURRENT_MODULE_NAME="$(basename "$0")"
source "${PROJECT_ROOT}/lib/logging.sh"

ssh::force_service_mode() {
    local units_to_stop=("ssh.socket" "ssh.service")
    
    log_info "Принудительный перевод SSH в Service Mode..."

    # 1. Сначала жестко останавливаем всё, что связано с SSH
    # Это очищает порты и убивает возможные конфликты
    for unit in "${units_to_stop[@]}"; do
        systemctl stop "$unit" >/dev/null 2>&1
    done

    # Сбрасываем счетчики ошибок сервисов systemd
    systemctl reset-failed

    # 2. Отключаем сокет полностью (Masking — лучший способ избежать автозапуска)
    systemctl disable ssh.socket >/dev/null 2>&1
    systemctl mask ssh.socket >/dev/null 2>&1

    # 3. Настраиваем и запускаем нужный сервис
    systemctl unmask ssh.service >/dev/null 2>&1
    systemctl enable ssh.service >/dev/null 2>&1
    
    if systemctl start ssh.service; then
        # 4. Проверка результата по факту, а не по процессу
        if systemctl is-active --quiet ssh.service; then
            log_success "SSH гарантированно запущен как ssh.service"
            return 0
        fi
    fi

    log_error "Критическая ошибка при запуске SSH"
    return 1
}

ssh::force_service_mode