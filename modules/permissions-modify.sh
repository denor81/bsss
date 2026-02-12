#!/usr/bin/env bash
# Создает файл конфигурации SSH для отключения логина по паролю и root
# MODULE_ORDER: 26
# MODULE_TYPE: modify
# MODULE_NAME: module.permissions.modify.name

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"
source "${PROJECT_ROOT}/modules/helpers/permissions.sh"

trap log_stop EXIT

# @type:        Orchestrator
# @description: Создает файл конфигурации SSH с настройками доступа
#               Отключает логин root и по паролю, включает вход по ключам
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               1 - ошибка создания файла
permissions::rules::make_bsss_rules() {
    local last_prefix new_prefix path

    last_prefix=$(permissions::ssh::find_last_prefix)

    if [[ -z "$last_prefix" ]]; then
        new_prefix="10"
    else
        new_prefix=$(( last_prefix + 10 ))
    fi

    path="${SSH_CONFIGD_DIR}/${new_prefix}${BSSS_PERMISSIONS_CONFIG_FILE_NAME}"

    log_info "Будет создан файл [$path]"
    io::confirm_action "Создать файл с правилами?"

    # Создаем файл с правами
    if cat > "$path" << EOF
# $BSSS_MARKER_COMMENT
# User permissions
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
EOF
    then
        log_info "Файл создан [$path]"
    else
        log_error "Ошибка при создании файла с правами доступа [$path])"
        return 1
    fi
}

permissions::orchestrator::dispatch_logic() {
    local menu_id="$1"

    case "$menu_id" in
        1) permissions::toggle::rules ;;
        *) log_error "$(_ "ufw.error.invalid_menu_id" "$menu_id")"; return 1 ;;
    esac
}

check_current_user() {
    local root_id auth_id auth_type
    root_id=$(id -u root)
    auth_id=$(id -u "$(logname)")
    auth_type="$1"

    log_info "Владелец сессии [$(logname)]|Тип подключения [$auth_type]"
    log_info "[nosudo>нет прав sudo] [nopass>не требует пароль при выполнении sudo]"
    log_info "[pass>требует пароль при выполнении sudo] [superuser>superuser]"
    user::info::block

    if (( root_id == auth_id )); then
        log_warn "Авторизируйтесь по SSH ключу обычным пользователем"
        log_warn "Подключитесь по SSH ключу пользователем отличным от root"
        return 1
    fi

    permissions::menu::display

    local menu_id
    menu_id=$(permissions::menu::get_user_choice | tr -d '\0')

    permissions::orchestrator::dispatch_logic "$menu_id"    
}

# @type:        Orchestrator
# @description: Проверяет условия и создает файл конфигурации при выполнении
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отмена пользователем или несоответствие условий
permissions::orchestrator::apply() {
    local current_conn_type

    current_conn_type=$(user::system::get_auth_method | tr -d '\0')

    case "$current_conn_type" in
        key) check_current_user "$current_conn_type" ;;
        pass) log_warn "Подключитесь по SSH ключу пользователем отличным от root"; return 1 ;;
        n/a) log_warn "Не удалось определить тип подключения"; return 1 ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля создания прав доступа
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               2 - отмена пользователем или несоответствие условий
main() {
    i18n::load
    log_start
    io::confirm_action "Запустить модуль?"
    permissions::orchestrator::apply
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
