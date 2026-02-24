#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Создает пользователя BSSS если существует только root

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && realpath ..)"

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"

trap log_stop EXIT

# @type:        Orchestrator
# @description: Создает пользователя BSSS, устанавливает пароль и права sudo
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно создан пользователь
#               1 ошибка создания пользователя или sudoers файла
#               $? другие ошибки
user::create::execute_with_logging() {
    local password
    password="$(user::pass::generate)"

    if ! user::create::execute; then
        log_error "$(_ "user.create.create_error")"
        return 1
    fi

    printf '%s:%s\0' "$BSSS_USER_NAME" "$password" | user::pass::set

    if ! user::sudoers::create_file; then
        log_error "$(_ "user.create.create_error")"
        return 1
    fi

    log_info "$(_ "user.create.menu.user_created" "$BSSS_USER_NAME")"
    log_info_no_log "$(_ "user.create.menu.password_no_log" "${BSSS_USER_NAME}:${password}")"
    log_info "$(_ "common.check_auth")"
    log_info "$(_ "common.copy_ssh_key")"
    log_info "$(_ "user.create.menu.after_copy_key")"
    user::log::del_reminder
}

# @type:        Orchestrator
# @description: Логирует напоминания об удалении пользователя
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
user::log::del_reminder() {
    log_info "$(_ "user.create.menu.reminder")"
    log_info_simple_tab "$(_ "user.create.menu.reminder_deluser")"
    log_info_simple_tab "$(_ "user.create.menu.reminder_find")"
    log_info_simple_tab "$(_ "user.create.menu.reminder_sudoers")"
    log_info_simple_tab "$(_ "user.create.menu.reminder_pgrep")"
    log_info_simple_tab "$(_ "user.create.menu.reminder_killall")"
}

# @type:        Orchestrator
# @description: Отображает информацию и меню для создания пользователя
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
user::main::menu::dispatcher() {
    log_info "$(_ "user.create.menu.header")"
    log_info_simple_tab "$(_ "user.create.menu.create_user" "$BSSS_USER_NAME" "$BSSS_USER_NAME")"
    log_info_simple_tab "$(_ "user.create.menu.generate_pass" "$BSSS_USER_PASS_LEN")"
    log_info_simple_tab "$(_ "user.create.menu.create_sudoers" "$SUDOERS_D_DIR" "$BSSS_USER_NAME")"
    log_info_simple_tab "$(_ "user.create.menu.password_once")"
    log_info "$(_ "user.create.menu.after_create")"
    log_info "$(_ "user.create.menu.check_key")"

    log_info "$(_ "common.menu_header")"
    log_info_simple_tab "1. $(_ "user.create.menu.item_create")"
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-1]$" "0-1" "^0$" | tr -d '\0') || return

    case "$menu_id" in
        1) user::create::execute_with_logging ;;
    esac
}

# @type:        Orchestrator
# @description: Обрабатывает сценарий когда в системе только root
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
user::orchestrator::need_add_bsssuser() {
    log_info "$(_ "user.check.only_root")"
    log_info "$(_ "user.create.menu.after_create")"
    user::info::block
    log_info "$(_ "user.create.menu.check_key")"
    user::main::menu::dispatcher
}

# @type:        Orchestrator
# @description: Обрабатывает сценарий когда есть другие пользователи, но нет bsssuser
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
user::orchestrator::can_add_bsssuser() {
    log_info "$(_ "user.check.user_count")"
    log_info "$(_ "user.create.other_users_exist")"
    log_info "$(_ "user.create.menu.after_create")"
    user::info::block
    log_info "$(_ "user.create.menu.check_key")"
    user::main::menu::dispatcher
}

# @type:        Orchestrator
# @description: Логирует сообщение что пользователь уже существует
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
user::log::no_new_user_needed() {
    log_info "$(_ "user.check.user_exists" "$BSSS_USER_NAME")"
    log_info "$(_ "user.create.other_users_exist")"
    user::info::block
    user::log::del_reminder
}

# @type:        Orchestrator
# @description: Диспетчеризирует логику проверки состояния пользователей
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               3 ошибка проверки состава пользователей
user::dispatch::logic() {
    local rc
    user::system::is_only_root || rc=$?
    case "$rc" in
        0) user::orchestrator::need_add_bsssuser ;;
        1) user::orchestrator::can_add_bsssuser ;;
        2) user::log::no_new_user_needed ;;
        3) log_error "$(_ "common.error.check_users")" ;;
    esac
}

# @type:        Orchestrator
# @description: Запускает модуль создания пользователя
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 успешно
#               2 отмена пользователем
#               3 ошибка проверки состава пользователей
main() {
    i18n::load
    log_start
    user::dispatch::logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
