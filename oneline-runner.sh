#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh)

set -euo pipefail

readonly ARCHIVE_URL="https://github.com/denor81/bsss/archive/refs/tags/v1.0.0.tar.gz"
readonly LINK_NAME="bsss"
readonly INSTALL_DIR="/opt/bsss"
readonly TEMP_PROJECT_DIR="/tmp/bsss-$$"
readonly EXIT_SUCCESS=0
readonly ERR_ALREADY_INSTALLED=1
readonly ERR_NO_ROOT=2
readonly ERR_UNPACK=3

hello() {
    log_info "Basic Server Security Setup (BSSS) - oneline запуск..."
}

handle_result() {
    local result=$1
    case $result in
        "$EXIT_SUCCESS") 
            log_success "Операция завершена"
            ;;
        "$ERR_NO_ROOT") 
            log_error "Запустите с sudo: sudo $0"
            ;;
        "$ERR_ALREADY_INSTALLED") 
            log_error "Уже установлен. Используйте: bsss --uninstall"
            ;;
        "$ERR_UNPACK") 
            log_error "Проверьте подключение к интернету"
            ;;
        *) 
            log_error "Неизвестная ошибка ($result)"
            ;;
    esac
    return $result
}

# Проверяем права root
check_root_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Для работы скрипта требуются права root"
        log_info "Пожалуйста, запускайте с sudo"
        return "$ERR_NO_ROOT"
    fi
}

# Спрашиваем пользователя о режиме запуска
ask_user_how_to_run(){
    log_info "Запустить bsss однократно?"
    log_info "Y - запуск однократно / n - установить / c - отмена"
    read -p "Ваш выбор (Y/n/c): " -n 1 -r

if [[ $REPLY =~ ^[Cc]$ ]]; then
    log_info "Отмена выполнения."
    # return 0 завершает функцию/скрипт успешно
    return 0 
elif [[ $REPLY =~ ^[Nn]$ ]]; then
    # Установка в систему
    install_to_system
    # После установки скрипт, вероятно, должен завершиться
    return 0 
else
    # Разовый запуск (любой другой ввод)
    log_info "Запускаюсь из временной директории $LOCAL_RUNNER_PATH"
    
    # Запускаем локальный runner в ОТДЕЛЬНОМ процессе с передачей всех аргументов
    # Передаем статус завершения дочернего скрипта как статус родительского
    bash "$LOCAL_RUNNER_PATH" "$@"
    # Можно явно не писать return, статус последнего выполненного процесса вернется автоматически
fi
}

# Создаём/удаляем временную директорию
create_tmp_dir() {
    mkdir -p "$TEMP_PROJECT_DIR"
    trap "rm -rf $TEMP_PROJECT_DIR" EXIT
    log_info "Создана временная директория $TEMP_PROJECT_DIR"
}

# Скаиваем архив
download_and_unpack_archive() {
log_info "Скачиваю архив с GitHub: $ARCHIVE_URL"
if ! curl -Ls "$ARCHIVE_URL" | tar xz -C "$TEMP_PROJECT_DIR"; then
    log_error "Ошибка при скачивании или распаковке архива."
    return "$ERR_UNPACK"
fi
}

# Проверяем успешность распаковки во временную директорию
check_archive_unpacking() {
LOCAL_RUNNER_PATH=$(find "$TEMP_PROJECT_DIR" -type f -name "local-runner.sh")
if [[ -z "$LOCAL_RUNNER_PATH" ]]; then
    log_error "Что то не так... либо ошибка при рапаковке архива, либо ошибка в путях."
    return "$ERR_UNPACK"
fi
log_success "Архив успешно распакован во временную директорию"
}

# Функция установки в систему
install_to_system() {
    # Проверяем, установлен ли уже скрипт
    if [[ -d "$INSTALL_DIR" ]]; then
        log_error "Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
        log_info "Для запуска Basic Server Security Setup используйте команду: sudo bsss, если не сработает - проверьте, что установлено в каталоге $INSTALL_DIR."
        log_info "Для удаления ранее установленного скрипта BSSS выполните: sudo bsss --uninstall"
        return "$ERR_ALREADY_INSTALLED"
    fi
    
    log_info "Устанавливаю BSSS в систему..."
    
    # Создаем директорию установки
    mkdir -p "$INSTALL_DIR"
    
    # Копируем файлы
    cp -r "$TEMP_PROJECT_DIR"/* "$INSTALL_DIR/"
    
    # Делаем скрипты исполняемыми
    chmod +x "$INSTALL_DIR"/*.sh
    chmod -R +x "$INSTALL_DIR"/modules
    
    # Создаем символическую ссылку с проверкой конфликта
    if [[ -L "$LINK_NAME" ]]; then
        log_error "Символическая ссылка $LINK_NAME уже существует - BSSS установлен."
        log_info "Ссылка указывает на: $(readlink "$LINK_NAME")."
        return "$ERR_ALREADY_INSTALLED"
    fi
    
    # Создаем символическую ссылку
    ln -s "$INSTALL_DIR/local-runner.sh" "$LINK_NAME"
    
    log_success "Установка завершена!"
    log_info "Для запуска используйте команду: sudo bsss"
    log_info "Для удаления выполните: sudo bsss --uninstall"
    return "$EXIT_SUCCESS"
}

log_success() { echo "[v] $1"; }
log_error() { echo "[x] $1" >&2; }
log_info() { echo "[*] $1"; }

hello
check_root_permissions
ask_user_how_to_run "$@"
create_tmp_dir
download_and_unpack_archive
check_archive_unpacking

main "$@"
handle_result $?
exit $?