#!/usr/bin/env bash
# Создает пользователя BSSS если существует только root
# MODULE_ORDER: 25
# MODULE_TYPE: modify
# MODULE_NAME: module.user.create.name

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
source "${PROJECT_ROOT}/lib/user_confirmation.sh"
source "${PROJECT_ROOT}/modules/helpers/common.sh"
source "${PROJECT_ROOT}/modules/helpers/user.sh"

trap log_stop EXIT

user::orchestrator::create_dispatcher() {
    local password
    password="$(user::pass::generate)"

    user::create::execute || { log_error "Ошибка при создании пользователя"; return; }
    printf '%s:%s\0' "$BSSS_USER_NAME" "$password" | user::pass::set
    user::sudoers::create_file || log_error "Ошибка при создании файла sudoers"

    printf '%s:%s' "$BSSS_USER_NAME" "$password"
}

# @type:        Orchestrator
# @description: Создает пользователя BSSS
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - ошибка при создании пользователя
user::orchestrator::create_user() {

    log_attention "Не закрывайте это окно терминала"
    log_info "Что будет происходить:"
    log_info_simple_tab "Создание: [useradd -m -d /home/$BSSS_USER_NAME -s /bin/bash -G sudo $BSSS_USER_NAME]"
    log_info_simple_tab "Генерация пароля: [openssl rand -base64 $BSSS_USER_PASS_LEN]"
    log_info_simple_tab "Создание правил в ${SUDOERS_D_DIR}/${BSSS_USER_NAME}"
    log_info_simple_tab "Пароль будет выведен только раз на экран терминала (в логи не пишется)"
    log_info "После создания пользователя необходимо скопировать ваш ключ командой ssh-copy-id"
    log_info "Проверить авторизацию по ключу и если все ок, то можно запрещать доступ по паролю и доступ от имени root"

    io::confirm_action "Создать пользователя $BSSS_USER_NAME?"
    local cred
    cred=$(user::orchestrator::create_dispatcher)

    log_info "Пользователь $BSSS_USER_NAME создан, пароль назначен"
    log_info_no_log "Не логируется >>>[${cred}]<<<"
    log_info "Проверьте возможность авторизации по логину и паролю"
    log_info "Скопируйте на сервер ключ для подключения по SSH [ssh-copy-id]"
    log_info "После копирования SSH ключа и успешного подключения можно будет запретить авторизацию по паролю"
    log_info "Напоминание, как удалить пользователя:"
    log_info_simple_tab "deluser --remove-home --remove-all-files USERNAME # Удалить пользователя"
    log_info_simple_tab "find / -uid USERID 2>/dev/null # Проверка найти все созданные файлы по id"
    log_info_simple_tab "pgrep -u USERNAME # посмотреть PID процессов"
    log_info_simple_tab "killall -9 -u USERNAME # завершить все процессы"
}

user::orchestrator::need_add_bsssuser() {
    log_info "В системе один единственный пользователь root"
    log_info "Настоятельно рекомендуется создать второго пользователя"
    user::info::block
    log_info "Вы можете создать пользователя $BSSS_USER_NAME автоматически или создать любого другого пользователя вручную"
    user::orchestrator::create_user
    log_info "Убедитесь, что вы можете подключиться по SSH ключу под нужным пользователем (не root), затем запрещайте авторизацию по паролю и доступ от root пользователя"
}

user::orchestrator::can_add_bsssuser() {
    log_info "Помимо пользователя root уже созданы другие пользователи"
    log_info "Авторизируйтесь по SSH ключу под пользователем отличным от root, чтобы отключить возможность авторизации по паролю и авторизацию под root"
    user::info::block
    log_info "Можно создать отдельного пользователя $BSSS_USER_NAME или авторизироваться под уже созданным"
    user::orchestrator::create_user
    log_info "Убедитесь, что вы можете подключиться по SSH ключу под нужным пользователем (не root), затем запрещайте авторизацию по паролю и доступ от root пользователя"
}

user::log::no_new_user_needed() {
    log_info "Пользователь $BSSS_USER_NAME уже создан"
    log_info "Созание дополнительного пользователя возможно только в ручную"
    user::info::block
    log_info "Убедитесь, что вы можете подключиться по SSH ключу под нужным пользователем (не root), затем запрещайте авторизацию по паролю и доступ от root пользователя"
}

user::dispatch::logic() {
    local rc
    user::system::is_only_root || rc=$?
    case "$rc" in
        0) user::orchestrator::need_add_bsssuser ;; # Только root > предлагаем создать пользователя
        1) user::orchestrator::can_add_bsssuser ;; # Есть другие пользователи, но нет bsssuser > предлагаем создать
        2) user::log::no_new_user_needed ;; # bsssuser создан > нет необходимости создавать нового
        3) log_error "Ошибка проверки состава пользователей" ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для модуля создания пользователя
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
main() {
    i18n::load
    log_start
    io::confirm_action "Запустить модуль?"
    user::dispatch::logic
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
