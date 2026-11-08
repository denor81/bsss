# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Orchestrator
# @description: Сохраняет согласованные нестандартные SSH порты или устанавливает случайный порт
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 порты настроены
#               1 порты после настройки не соответствуют ожидаемым
#               $? ошибка настройки
auto::ssh::configure() {
    local configured active port
    configured=$(ssh::port::get_configured | tr '\0' ',')
    active=$(ssh::port::get_from_ss | tr '\0' ',')

    if [[ -n "$configured" && "$configured" == "$active" ]] && ! ssh::port::has_default "$configured"; then
        log_info "$(_ "auto.info.already_configured" "$(_ "module.ssh.name")")"
        return 0
    fi

    port=$(ssh::port::generate_free_random_port | tr -d '\0')
    [[ -n "$port" ]]
    ssh::log::guard_instructions "$port"
    printf '%s\0' "$port" | ssh::rule::reset_and_pass | ufw::rule::reset_and_pass | ssh::port::install_new
    sys::service::restart
    ssh::port::wait_for_up "$port"

    configured=$(ssh::port::get_configured | tr '\0' ',')
    active=$(ssh::port::get_from_ss | tr '\0' ',')
    if [[ "$configured" != "$port," || "$active" != "$configured" ]]; then
        log_error "$(_ "auto.error.ssh_ports")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Разрешает активные SSH порты и включает UFW
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 UFW настроен
#               1 активные SSH порты отсутствуют
#               $? ошибка добавления правил или включения UFW
auto::ufw::enable() {
    local ports
    ports=$(ssh::port::get_from_ss | tr '\0' '\n')
    if [[ -z "$ports" ]]; then
        log_error "$(_ "common.helpers.ssh.no_active_ports")"
        return 1
    fi

    printf '%s\n' "$ports" | tr '\n' '\0' | ufw::rule::add_bsss
    ufw status >/dev/null
    if ufw::status::is_active; then
        log_info "$(_ "auto.info.already_configured" "$(_ "module.ufw.name")")"
    else
        ufw::status::force_enable
    fi
}

# @type:        Orchestrator
# @description: Блокирует ping, сохраняя уже созданную настройку и исходный бэкап
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 ping настроен
#               $? ошибка настройки
auto::ping::disable() {
    if ufw::ping::is_configured; then
        log_info "$(_ "auto.info.already_configured" "$(_ "ufw.menu.item_ping_disable")")"
        return 0
    fi

    ufw::orchestrator::disable_ping
    ufw::status::reload
}

# @type:        Orchestrator
# @description: Применяет полный шаблон доступа SSH, если итоговые значения отличаются
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 шаблон применен
#               1 итоговые значения отличаются от шаблона
#               $? ошибка настройки
auto::permissions::configure() {
    sshd -t
    if permissions::rules::is_effective; then
        log_info "$(_ "auto.info.already_configured" "$(_ "module.permissions.modify.name")")"
        return 0
    fi

    permissions::rules::restore
    permissions::rules::make_bsss_rules
    sys::service::restart
    permissions::rules::is_effective
}
