# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Проверяет Ubuntu, работающий systemd и наличие конфигурации GRUB
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 окружение поддерживается
#               1 окружение не поддерживается
sys::environment::check() {
    local ID="" VERSION_ID=""
    if [[ ! -r /etc/os-release ]]; then
        log_error "$(_ "dependencies.os_unsupported")"
        return 1
    fi
    source /etc/os-release
    if [[ "$ID" != ubuntu || ! "$VERSION_ID" =~ ^[0-9]+\.[0-9]+$ ]] || (( ${VERSION_ID%%.*} < 20 )); then
        log_error "$(_ "dependencies.os_unsupported")"
        return 1
    fi
    if ! command -v systemctl >/dev/null 2>&1 || ! command -v journalctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
        log_error "$(_ "dependencies.systemd_required")"
        return 1
    fi
    if ! systemctl show --property=Version --value >/dev/null 2>&1; then
        log_error "$(_ "dependencies.systemd_required")"
        return 1
    fi
    if ! command -v update-grub >/dev/null 2>&1 || [[ ! -f /etc/default/grub || ! -d /boot/grub ]]; then
        log_error "$(_ "dependencies.grub_required")"
        return 1
    fi
}

# @type:        Orchestrator
# @description: Проверяет обязательные команды и устанавливает недостающие пакеты одним вызовом apt
# @stdin:       нет (подтверждение через TTY)
# @stdout:      нет
# @exit_code:   0 зависимости доступны
#               1 ошибка установки или проверки
#               2 отказ пользователя
sys::dependencies::check() {
    log_info "$(_ "dependencies.check")"
    sys::environment::check
    local entry name package
    local -a missing=()
    local -A seen=()
    local -a requirements=(
        file:file gpg:gnupg gawk:gawk ufw:ufw openssl:openssl sudo:sudo
        ss:iproute2 sshd:openssh-server useradd:passwd chpasswd:passwd
        fallocate:util-linux mkswap:util-linux swapon:mount swapoff:mount
        unattended-upgrade:unattended-upgrades dpkg-reconfigure:debconf
        numfmt:coreutils shuf:coreutils realpath:coreutils nohup:coreutils
        find:findutils xargs:findutils grep:grep sed:sed tar:tar gzip:gzip
    )
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "$(_ "dependencies.apt_missing")"
        return 1
    fi
    for entry in "${requirements[@]}"; do
        name=${entry%%:*}
        package=${entry#*:}
        if ! command -v "$name" >/dev/null 2>&1; then
            if [[ -z "${seen[$package]:-}" ]]; then
                missing+=("$package")
                seen[$package]=1
            fi
        fi
    done
    if (( ${#missing[@]} > 0 )); then
        log_info "$(_ "dependencies.missing" "${missing[*]}")"
        io::confirm_action "$(_ "dependencies.confirm")"
        if ! log::command::run --info apt-get update; then
            log_error "$(_ "dependencies.failed")"
            return 1
        fi
        if ! log::command::run --info apt-get install -y "${missing[@]}"; then
            log_error "$(_ "dependencies.failed")"
            return 1
        fi
    fi
    for entry in "${requirements[@]}"; do
        name=${entry%%:*}
        if ! command -v "$name" >/dev/null 2>&1; then
            log_error "$(_ "dependencies.unavailable" "$name")"
            return 1
        fi
    done
    log_info "$(_ "dependencies.ready")"
}
