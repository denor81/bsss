#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh)

set -Eeuo pipefail

readonly UTIL_NAME="bsss"
readonly ARCHIVE_URL="file:///tmp/TEST.tar.gz"
# readonly ARCHIVE_URL="https://github.com/denor81/$UTIL_NAME/archive/refs/tags/v1.0.0.tar.gz"
readonly INSTALL_DIR="/opt/$UTIL_NAME"
readonly LOCAL_RUNNER_FILE_NAME="local-runner.sh"
declare -a CLEANUP_COMMANDS
TMPARCHIVE=""

ONETIME_RUN_FLAG=false
SYS_INSTALL_FLAG=false
CLEANUP_DONE_FLAG=false

readonly SUCCESS=0
readonly ERR_ALREADY_INSTALLED=1
readonly ERR_NO_ROOT=2
readonly ERR_DOWNLOAD=3
readonly ERR_UNPACK=4
readonly ERR_CHECK_UNPACK=5

# Очистка временных файлов
# shellcheck disable=SC2329
cleanup_handler() {
    if [ "$CLEANUP_DONE_FLAG" == "true" ]; then
        return "$SUCCESS" # Уже запускали, выходим
    fi
    local reason="$1" 
    log_info "Запуск процедуры очистки по причине: $reason..."

    # Проходим по всем командам в массиве в обратном порядке (опционально, но логично)
    for i in "${!CLEANUP_COMMANDS[@]}"; do
        CMD="${CLEANUP_COMMANDS[$i]}"
        log_info "Удаляем: $CMD"
        # Используем eval для выполнения сохраненной строки команды
        eval "$CMD"
        # Удаляем выполненную команду из массива (опционально)
        unset 'CLEANUP_COMMANDS[$i]'
    done
    log_success "Очистка завершена"
    CLEANUP_DONE_FLAG=true
    return "$SUCCESS"
}

# Передаем имя сигнала в функцию при вызове
trap 'cleanup_handler EXIT' EXIT
trap 'cleanup_handler ERR' ERR
# trap 'cleanup_handler SIGINT' SIGINT
# trap 'cleanup_handler SIGTERM' SIGTERM

hello() {
    log_info "Basic Server Security Setup (BSSS) - oneline запуск..."
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
    echo ""

    if [[ $REPLY =~ ^[Cc]$ ]]; then
        log_info "Выход"
        return $SUCCESS
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        # Проверяем, установлен ли уже скрипт
        if [[ -d "$INSTALL_DIR" ]]; then
            log_error "Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
            log_info "Для запуска Basic Server Security Setup используйте команду: sudo bsss, если не сработает - проверьте, что установлено в каталоге $INSTALL_DIR."
            log_info "Для удаления ранее установленного скрипта BSSS выполните: sudo bsss --uninstall"
            return "$ERR_ALREADY_INSTALLED"
        fi
        SYS_INSTALL_FLAG=true
    else
        log_info "Выбран разовый запуск"
        ONETIME_RUN_FLAG=true
    fi
    return $SUCCESS
}

# Создаём временную директорию
create_tmp_dir() {
    TEMP_PROJECT_DIR=$(mktemp -d --tmpdir "$UTIL_NAME"-XXXXXX)
    CLEANUP_COMMANDS+=("rm -rf $TEMP_PROJECT_DIR")
    log_info "Создана временная директория $TEMP_PROJECT_DIR"
    return $SUCCESS
}

# Скаиваем архив во временный файл
download_archive() {
    local curl_output=""
    log_info "Скачиваю архив с GitHub: $ARCHIVE_URL"
    TMPARCHIVE=$(mktemp --tmpdir "$UTIL_NAME"-archive-XXXXXX)
    CLEANUP_COMMANDS+=("rm -f $TMPARCHIVE")
    curl_output=$(curl -fsSL "$ARCHIVE_URL" -o "$TMPARCHIVE" 2>&1 ) || { 
        log_error "Ошибка загрузки архива - $curl_output"
        return $ERR_DOWNLOAD
    }
    local fsize=""
    fsize=$(stat -c "%s" "$TMPARCHIVE" | awk '{printf "%.2f KB\n", $1/1024}')
    log_info "Архив скачан в $TMPARCHIVE (размер: $fsize, тип: $(file -ib "$TMPARCHIVE"))"
    return $SUCCESS
}

unpack_archive() {
    local tar_output=""
    tar_output=$(tar -xzf "$TMPARCHIVE" -C "$TEMP_PROJECT_DIR" 2>&1 ) || {
        log_error "Ошибка распаковки архива - $tar_output"
        return $ERR_UNPACK
    }
    local dir_size=""
    dir_size=$(du -sb "$TEMP_PROJECT_DIR" | cut -f1 | awk '{printf "%.2f KB\n", $1/1024}' )
    log_info "Архив распакован в $TEMP_PROJECT_DIR (размер: $dir_size)"
    return $SUCCESS
}

# Проверяем успешность распаковки во временную директорию
check_archive_unpacking() {
    LOCAL_RUNNER_PATH=$(find "$TEMP_PROJECT_DIR" -type f -name "$LOCAL_RUNNER_FILE_NAME")
    if [[ -z "$LOCAL_RUNNER_PATH" ]]; then
        log_error "При проверке наличия исполняемого файла произошла ошибка - файл $LOCAL_RUNNER_FILE_NAME не найден - что то не так... либо ошибка при рапаковке архива, либо ошибка в путях."
        return "$ERR_CHECK_UNPACK"
    fi
    log_info "Исполняемый файл $LOCAL_RUNNER_FILE_NAME найден"
}

onetime_run() {
    if [[ "$ONETIME_RUN_FLAG" = "true" ]]; then
        log_info "Единоразовый запуск $LOCAL_RUNNER_PATH"
        # запускаем в отдельном процессе и ждем завершение
        bash "$LOCAL_RUNNER_PATH" "$@"
        return $SUCCESS
    fi
}

Создайте символическую ссылку в /usr/local/bin:
Вам понадобятся права суперпользователя (sudo) для записи в этот системный каталог.

# Функция установки в систему
install_to_system() {
    log_info "Устанавливаю BSSS в систему..."
    
    # Создаем директорию установки
    mkdir -p "$INSTALL_DIR"
    
    # Копируем файлы
    cp -r "$(dirname "$LOCAL_RUNNER_PATH")"/* "$INSTALL_DIR/"
    
    # Делаем скрипты исполняемыми
    chmod +x "$INSTALL_DIR"/*.sh
    chmod -R +x "$INSTALL_DIR"/modules
    
    # Создаем символическую ссылку с проверкой конфликта
    if [[ -L "$UTIL_NAME" ]]; then
        log_error "Символическая ссылка $UTIL_NAME уже существует - BSSS установлен."
        log_info "Ссылка указывает на: $(readlink "$UTIL_NAME")."
        return "$ERR_ALREADY_INSTALLED"
    fi
    
    # Создаем символическую ссылку
    ln -s "$INSTALL_DIR/local-runner.sh" "$UTIL_NAME"
    
    log_success "Установка в систему завершена"
    log_info "Для запуска используйте команду: sudo bsss"
    log_info "Для удаления выполните: sudo bsss --uninstall"
    return "$SUCCESS"
}

log_success() { echo "[v] $1"; }
log_error() { echo "[x] $1" >&2; }
log_info() { echo "[*] $1"; }

main() {
    hello
    check_root_permissions
    ask_user_how_to_run
    if [[ "$ONETIME_RUN_FLAG" == "true" || "$SYS_INSTALL_FLAG" == "true" ]]; then
        create_tmp_dir
        download_archive
        unpack_archive
        check_archive_unpacking
    fi
    if [[ "$ONETIME_RUN_FLAG" == "true" ]]; then
        onetime_run "$@"
    fi
    if [[ "$SYS_INSTALL_FLAG" == "true" ]]; then
        install_to_system
    fi
}

main "$@"
log_success "Oneline запуск завершен успешно"
exit $?