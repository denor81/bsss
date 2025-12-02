#!/usr/bin/env bash
# oneline-runner.sh
# Загрузчик для установки проекта одной командой
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh)

set -Eeuo pipefail

readonly UTIL_NAME="bsss"
readonly SYMBOL_LINK_PATH="/usr/local/bin/$UTIL_NAME"
readonly ARCHIVE_URL="file:///tmp/project-v1.0.0.tar.gz"
# readonly ARCHIVE_URL="https://github.com/denor81/$UTIL_NAME/archive/refs/tags/v1.0.0.tar.gz"
readonly INSTALL_DIR="/opt/$UTIL_NAME"
readonly INSTALL_LOG_FILE_NAME=".uninstall_paths"
readonly LOCAL_RUNNER_FILE_NAME="local-runner.sh"
declare -a CLEANUP_COMMANDS
TMPARCHIVE=""

ONETIME_RUN_FLAG=0
SYS_INSTALL_FLAG=0
CLEANUP_DONE_FLAG=0

readonly SUCCESS=0
readonly ERR_ALREADY_INSTALLED=1
readonly ERR_NO_ROOT=2
readonly ERR_DOWNLOAD=3
readonly ERR_UNPACK=4
readonly ERR_CHECK_UNPACK=5
readonly ERR_INCORRECT_CHOICE=6

log_success() { echo "[v] $1"; }
log_error() { echo "[x] $1" >&2; }
log_info() { echo "[ ] $1"; }

# Очистка временных файлов
# shellcheck disable=SC2329
cleanup_handler() {
    if [ "$CLEANUP_DONE_FLAG" -eq 1 ]; then
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
    CLEANUP_DONE_FLAG=1
    return "$SUCCESS"
}

# Передаем имя сигнала в функцию при вызове
trap 'cleanup_handler EXIT' EXIT
trap 'cleanup_handler ERR' ERR

hello() {
    log_info "Basic Server Security Setup (${UTIL_NAME^^}) - oneline запуск..."
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
    log_info "Запустить ${UTIL_NAME^^} однократно?"
    log_info "Y - запуск однократно / n - установить / c - отмена"
    local choice

    while true; do
        read -p "[ ] Ваш выбор (Y/n/c): " -r
        input=${REPLY:-Y}  # Если пустая строка, то Y по умолчанию
        
        # Проверка на допустимые символы (регистронезависимая для Y)
        if [[ ${input,,} =~ ^[ync]$ ]]; then
            choice=${input,,}
            break
        fi
        
        log_info "Неверный выбор. Пожалуйста, введите Y, n или c."
    done

    if [[ $choice =~ ^[Cc]$ ]]; then
        log_info "Выбрана отмена ($choice)"
        return $SUCCESS
    elif [[ $choice =~ ^[Nn]$ ]]; then
        log_info "Выбрана установка ($choice)"
        # Проверяем, установлен ли уже скрипт
        if [[ -d "$INSTALL_DIR" ]]; then
            log_error "Скрипт уже установлен в системе или установлен другой скрипт с таким же именем каталога."
            log_info "Для запуска Basic Server Security Setup (${UTIL_NAME^^}) используйте команду: sudo $UTIL_NAME, если не сработает - проверьте, что установлено в каталоге $INSTALL_DIR (ll $INSTALL_DIR) или куда ссылкается ссылка $UTIL_NAME (find /bin /usr/bin /usr/local/bin -type l -ls | grep $UTIL_NAME или realpath $UTIL_NAME)"
            log_info "Для удаления ранее установленного скрипта ${UTIL_NAME^^} выполните: sudo $UTIL_NAME --uninstall"
            return "$ERR_ALREADY_INSTALLED"
        fi
        SYS_INSTALL_FLAG=1
        return $SUCCESS
    elif [[ $choice =~ ^[Yy]$ ]]; then
        log_info "Выбран разовый запуск ($choice)"
        ONETIME_RUN_FLAG=1
        return $SUCCESS
    else
        log_error "Не корректное значение ($choice)"
        return $ERR_INCORRECT_CHOICE
    fi
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
    curl_output=$(curl -fsSL "$ARCHIVE_URL" -o "$TMPARCHIVE" 2>&1) || { 
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
    TMP_LOCAL_RUNNER_PATH=$(find "$TEMP_PROJECT_DIR" -type f -name "$LOCAL_RUNNER_FILE_NAME")
    if [[ -z "$TMP_LOCAL_RUNNER_PATH" ]]; then
        log_error "При проверке наличия исполняемого файла произошла ошибка - файл $LOCAL_RUNNER_FILE_NAME не найден - что то не так... либо ошибка при рапаковке архива, либо ошибка в путях."
        return "$ERR_CHECK_UNPACK"
    fi
    log_info "Исполняемый файл $LOCAL_RUNNER_FILE_NAME найден"
}

# Добавляет путь в файл лога установки для последующего удаления
_add_uninstall_path() {
    local uninstall_path="$1"
    local install_log_path="$INSTALL_DIR/$INSTALL_LOG_FILE_NAME"

    # Добавляем путь в файл лога, если его там еще нет
    if ! grep -Fxq "$uninstall_path" "$install_log_path" 2>/dev/null; then
        echo "$uninstall_path" >> "$install_log_path"
        log_info "Путь $uninstall_path добавлен в лог удаления $install_log_path"
    fi
    
    return "$SUCCESS"
}

# Функция установки в систему
install_to_system() {
    log_info "Устанавливаю ${UTIL_NAME^^} в систему..."
    local tmp_dir_path=""
    local local_runner_path="$INSTALL_DIR/$LOCAL_RUNNER_FILE_NAME"
    tmp_dir_path=$(dirname "$TMP_LOCAL_RUNNER_PATH")

    # Проверка существования символической ссылки
    if [[ -L "$SYMBOL_LINK_PATH" ]]; then
        log_error "Символическая ссылка $UTIL_NAME уже существует - запускайте sudo $UTIL_NAME, если не сработает - проверьте куда ссылается $UTIL_NAME"
        return "$ERR_ALREADY_INSTALLED"
    fi

    # Создаем директорию установки
    log_info "Создаю директорию $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # Добавляем директорию установки в лог удаления
    _add_uninstall_path "$INSTALL_DIR"
    
    # Копируем файлы
    log_info "Копирую файлы из временной директории $tmp_dir_path в $INSTALL_DIR"
    cp -r "$tmp_dir_path"/* "$INSTALL_DIR/"

    # Создание символической ссылки
    ln -s "$local_runner_path" "$SYMBOL_LINK_PATH"
    log_info "Создана символическая ссылка $UTIL_NAME для запуска $local_runner_path. (Расположение ссылки: $(dirname "$SYMBOL_LINK_PATH"))"
    _add_uninstall_path "$SYMBOL_LINK_PATH"

    # Делаем скрипты исполняемыми
    log_info "Устанавливаю права запуска (+x) в $INSTALL_DIR для .sh файлов"
    chmod +x "$INSTALL_DIR"/*.sh

    log_success "Установка в систему завершена"
    log_info "Для запуска: sudo $UTIL_NAME"
    log_info "Для удаления: sudo $UTIL_NAME --uninstall"
    return "$SUCCESS"
}

main() {
    hello
    check_root_permissions
    ask_user_how_to_run
    if [[ "$ONETIME_RUN_FLAG" -eq 1 || "$SYS_INSTALL_FLAG" -eq 1 ]]; then
        create_tmp_dir
        download_archive
        unpack_archive
        check_archive_unpacking
    fi
    if [[ "$ONETIME_RUN_FLAG" -eq 1 ]]; then
        bash "$TMP_LOCAL_RUNNER_PATH" "$@"
    fi
    if [[ "$SYS_INSTALL_FLAG" -eq 1 ]]; then
        install_to_system
    fi
}

main "$@"
log_success "Oneline запуск завершен успешно"
