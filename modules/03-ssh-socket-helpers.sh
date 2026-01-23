#!/usr/bin/env bash
# Хелперы для работы с SSH socket/service режимами
# MODULE_TYPE: helper

set -Eeuo pipefail

# @type:        Filter
# @description: Проверяет, настроен ли SSH в service mode
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - SSH уже настроен в service mode
#               1 - требуется настройка
ssh::is_already_configured() {
    # Если сервис активен И сокет замаскирован — значит, мы уже всё настроили
    if systemctl is-active --quiet ssh.service && [[ "$(systemctl is-enabled ssh.socket 2>/dev/null)" == "masked" ]]; then
        return 0 # Всё уже как надо
    fi
    return 1 # Нужно вмешательство
}

# @type:        Orchestrator
# @description: Принудительно переключает SSH в service mode
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - SSH успешно переведен в service mode
#               1 - ошибка при запуске SSH
ssh::force_service_mode() {
    local units_to_stop=("ssh.socket" "ssh.service")
    
    log_info "Принудительный перевод SSH в Service Mode..."

    # 1. Сначала жестко останавливаем всё, что связано с SSH
    # Это очищает порты и убивает возможные конфликты
    for unit in "${units_to_stop[@]}"; do
        systemctl stop "$unit" >/dev/null 2>&1
    done

    # 2. Отключаем сокет полностью (Masking — лучший способ избежать автозапуска)
    systemctl disable ssh.socket >/dev/null 2>&1
    systemctl mask ssh.socket >/dev/null 2>&1

    # 3. Настраиваем и запускаем сервис
    systemctl unmask ssh.service >/dev/null 2>&1
    systemctl enable ssh.service >/dev/null 2>&1
    
    if systemctl start ssh.service; then
        # 4. Проверка результата по факту, а не по процессу
        if systemctl is-active --quiet ssh.service; then
            log_success "SSH гарантированно запущен как сервис [ssh.service]"
            return 0
        fi
    fi

    log_error "Критическая ошибка при запуске SSH"
    return 1
}

