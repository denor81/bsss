
1. Архитектура Rollback-механизма
Мы добавим в твой Orchestrator логику «Сторожа». Основная сложность здесь — передать функции в фоновый процесс, который выживет после закрытия твоей сессии.
# @type:        Orchestrator
# @description: Полная очистка системы от следов BSSS и деактивация UFW.
#               Вызывается при критическом сбое или таймауте.
# @exit_code:   0 - всегда
orchestrator::total_rollback() {
    log_warn "ROLLBACK: Инициирован полный демонтаж настроек BSSS..."

    # 1. Удаляем файлы конфигурации SSH (твой метод)
    ssh::remove_bsss_configs 

    # 2. Полная деактивация UFW для гарантии доступа
    if command -v ufw >/dev/null; then
        ufw --force disable >/dev/null 2>&1
        log_success "UFW: Полностью деактивирован (безопасный режим)."
    fi

    # 3. Перезагрузка сервиса
    systemctl daemon-reload
    systemctl restart ssh
    
    log_success "ROLLBACK: Система возвращена к исходному состоянию. Проверьте доступ по старым портам."
}

# @type:        Orchestrator
# @description: Фоновый процесс-таймер. Не зависит от жизни родительской сессии.
# @params:      $1 - PID родителя (скрипта)
orchestrator::watchdog_timer() {
    local parent_pid="$1"
    local timeout=300 # 5 минут

    # Ждем молча
    sleep "$timeout"

    # Если мы дошли сюда, значит подтверждение не получено
    # Пытаемся завершить основной скрипт, если он еще жив
    kill "$parent_pid" 2>/dev/null || true
    
    # Выполняем откат
    orchestrator::total_rollback
}


2. Интеграция в основной пайплайн
Теперь изменим orchestrator::bsss_config_not_exists (и логику переустановки), чтобы запустить таймер. Мы используем export -f, чтобы передать функции в nohup.


orchestrator::apply_with_guard() {
    local current_pid=$$

    # 1. Запуск сторожа в фоне
    # Экспортируем функции, чтобы они были доступны внутри nohup
    export -f orchestrator::total_rollback ssh::remove_bsss_configs log_warn log_success
    
    log_info "Запуск таймера безопасности (5 минут)..."
    nohup bash -c "orchestrator::watchdog_timer '$current_pid'" >/dev/null 2>&1 &
    local watchdog_pid=$!

    # 2. Применение изменений (твой пайплайн)
    # Предполагаем, что здесь меняется порт и рестартится SSH
    ssh::ask_new_port | ssh::install_new_port_with_ufw 

    # 3. Ожидание подтверждения
    io::draw_border
    log_info "ВНИМАНИЕ: Настройки применены."
    log_info "1. ОТКРОЙТЕ НОВОЕ ОКНО ТЕРМИНАЛА."
    log_info "2. Попробуйте подключиться по новому порту."
    log_info "Если вы не подтвердите связь, через 5 минут произойдет ОТКАТ."
    
    local user_confirm
    if io::ask_value "Для подтверждения введите 'connected'" "" "^connected$" "слово 'connected'"; then
        # Если ввели верно - убиваем таймер
        kill "$watchdog_pid" 2>/dev/null || true
        log_success "Изменения зафиксированы. Таймер отката отключен."
    else
        # Сработает, если скрипт прервется или введут не то
        kill "$watchdog_pid" 2>/dev/null || true
        orchestrator::total_rollback
    fi
}
