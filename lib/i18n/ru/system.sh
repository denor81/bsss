# System messages (Russian)

# Update module
I18N_MESSAGES["system.update.apt_not_found"]="Менеджер пакетов apt-get не найден"
I18N_MESSAGES["system.update.error"]="Ошибка при обновлении системных пакетов"
I18N_MESSAGES["system.update.confirm"]="Обновить системные пакеты? [apt-get update && apt-get upgrade -y]"

# Reload check module
I18N_MESSAGES["system.reload.not_required"]="Перезагрузка не требуется"
I18N_MESSAGES["system.reload.reboot_required"]="Система нуждается в перезагрузке %s"
I18N_MESSAGES["system.reload.pkgs_header"]="Пакеты требующие перезагрузки:"

# Common helpers
I18N_MESSAGES["common.helpers.validate_order.error_missing_tag"]="Отсутствует обязательный тег MODULE_ORDER: %s"
I18N_MESSAGES["common.helpers.validate_order.error_duplicate"]="Дублирующийся MODULE_ORDER (%s): %s"
I18N_MESSAGES["common.helpers.file.delete.error"]="Ошибка удаления %s: %s"
I18N_MESSAGES["common.helpers.file.delete.success"]="Удалено: %s"
I18N_MESSAGES["common.helpers.ssh.no_active_ports"]="Нет активных SSH портов [ss -ltnp]"
I18N_MESSAGES["common.helpers.ssh.active_ports"]="Есть активные SSH порты [ss -ltnp]: %s"
I18N_MESSAGES["common.helpers.ufw.rules_found"]="Есть правила UFW [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules_not_found"]="Нет правил UFW [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules.sync"]="Правила UFW синхронизированы с настройками ${UTIL_NAME^^} для SSH порта"
I18N_MESSAGES["common.helpers.ufw.rules.delete_warning"]="Удаляя правила SSH, также будут удалены связанные правила UFW"
I18N_MESSAGES["common.helpers.ufw.rule.deleted"]="Удалено правило UFW: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.delete_error"]="Ошибка при удалении правила UFW: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.added"]="Создано правило UFW: [ufw allow %s/tcp comment ${UTIL_NAME^^}]"
I18N_MESSAGES["common.helpers.ufw.rule.add_error"]="Ошибка при добавлении правила UFW: [ufw allow %s/tcp comment ${UTIL_NAME^^}]"
I18N_MESSAGES["common.helpers.ufw.disabled"]="UFW: Полностью деактивирован [ufw --force disable]"
I18N_MESSAGES["common.helpers.ufw.already_disabled"]="UFW: деактивирован"
I18N_MESSAGES["common.helpers.rollback.stop_signal"]="Посылаем сигнал отключения rollback USR1 [PID: %s]"
I18N_MESSAGES["common.helpers.rollback.stop_received"]="Получен сигнал USR1 - остановка скрипта из-за отката"
I18N_MESSAGES["common.helpers.rollback.exit_received"]="Получен сигнал EXIT [RC: %s]"
I18N_MESSAGES["common.helpers.rollback.int_received"]="Получен сигнал INT [RC: %s]"
I18N_MESSAGES["common.helpers.rollback.fifo_created"]="Создан FIFO: %s"

# Init helpers
I18N_MESSAGES["init.gawk.not_installed"]="Критическая зависимость - 'gawk' не установлен"
I18N_MESSAGES["init.gawk.nul_explanation"]="Этот проект использует NUL-разделители, которые корректно поддерживает только GNU Awk"
I18N_MESSAGES["init.gawk.install_confirm"]="Установить gawk сейчас? [apt update && apt install gawk -y]"
I18N_MESSAGES["init.gawk.install_success"]="gawk успешно установлен"
I18N_MESSAGES["init.gawk.install_error"]="Ошибка при установке gawk"

# UFW check
I18N_MESSAGES["ufw.check.not_installed"]="UFW не установлен"
I18N_MESSAGES["ufw.check.install_confirm"]="Установить UFW сейчас? [apt update && apt install ufw -y]"
I18N_MESSAGES["ufw.check.install_error"]="Ошибка при установке UFW"
I18N_MESSAGES["ufw.check.install_success"]="UFW успешно установлен"
I18N_MESSAGES["ufw.check.installed_restart"]="UFW установлен - перезапустите скрипт"

# SSH socket helpers
I18N_MESSAGES["ssh.socket.force_mode"]="Принудительное переключение SSH в Service Mode..."
I18N_MESSAGES["ssh.socket.service_not_active"]="Сервис не запущен. Пытаюсь стартовать..."
I18N_MESSAGES["ssh.socket.start_error"]="Не удалось запустить ssh.service. Проверьте 'journalctl -xeu ssh.service'"
I18N_MESSAGES["ssh.socket.active"]="SSH активен (Service Mode)"

# OS check
I18N_MESSAGES["os.check.file_not_found"]="Файл не существует: %s"
I18N_MESSAGES["os.check.unsupported"]="Система %s не поддерживается (ожидалось: %s)"
I18N_MESSAGES["os.check.supported"]="Система %s поддерживается"
