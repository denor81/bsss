#!/usr/bin/env bash
# Создает пользователя BSSS если существует только root
# MODULE_ORDER: 25
# MODULE_TYPE: modify
# MODULE_NAME: module.user.create.name

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"

trap log_stop EXIT

# @type:        Orchestrator
# @description: Создает пользователя BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка при создании пользователя
user::orchestrator::create_user() {
    local password

    io::confirm_action "Создать пользователя $BSSS_USER_NAME?"

    log_attention "Не закрывайте это окно терминала"

    log_info "Создание пользователя: $BSSS_USER_NAME"

    if ! user::create::execute; then
        log_error "Ошибка при создании пользователя"
        return 1
    fi
    log_info "Пользователь создан"

    password="$(user::pass::generate)"

    if [[ -z "$password" ]]; then
        log_error "openssl не найден, невозможно сгенерировать пароль"
        return 1
    fi

    printf '%s:%s\0' "$BSSS_USER_NAME" "$password" | user::pass::set
    log_info "Пароль установлен"

    log_info_no_log "Пользователь '$BSSS_USER_NAME' создан. Пароль: $password"

    log_info "Проверьте возможность авторизации по логину и паролю"
    log_info "Скопируйте на сервер ключ для подключения по SSH [ssh-copy-id]"
    log_info "После копирования SSH ключа и успешного подключения можно бует запретить авторизацию о паролю"
}

user::dispatch::logic() {
    if user::system::is_only_root; then
        user::orchestrator::create_user
    else
        local current_conn_type=$(user::system::get_auth_method | tr -d '\0')
        log_success "Пользователь отличный от root уже создан"
        user::info::block

        if [[ "$current_conn_type" == "PUBLICKEY" ]]; then
            local root_id=$(id -u root)
            local auth_id=$(id -u $(logname))
            log_success "Текущее подключение через [${current_conn_type}]"

            log_info "Текущий подключенный пользователь [Username: $(logname), UID: ${auth_id}]"
            if (( ! (root_id == auth_id) )); then
                log_success "Можно отключать PermitRootLogin и PasswordAuthentication"
                io::confirm_action "Отключить?"
            else
                log_warn "Нельзя отключать PermitRootLogin и PasswordAuthentication"
                log_warn "Подключитесь по SSH ключу пользователем отличным от root"
            fi
        else
            log_warn "Текущее подключение через [${current_conn_type}]"
            log_warn "Подключитесь по SSH ключу пользователем отличным от root"
        fi
    fi
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля создания пользователя
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    log_start
    io::confirm_action "Запустить модуль?"
    user::dispatch::logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
