# System messages (English)

# Update module
I18N_MESSAGES["system.update.apt_not_found"]="Package manager apt-get not found"
I18N_MESSAGES["system.update.error"]="Error updating system packages"
I18N_MESSAGES["system.update.confirm"]="Update system packages? [apt-get update && apt-get upgrade -y]"

# Reload check module
I18N_MESSAGES["system.reload.not_required"]="Reboot not required"
I18N_MESSAGES["system.reload.reboot_required"]="System requires reboot %s"
I18N_MESSAGES["system.reload.pkgs_header"]="Packages requiring reboot:"

# Common helpers
I18N_MESSAGES["common.helpers.validate_order.error_missing_tag"]="Missing required MODULE_ORDER tag: %s"
I18N_MESSAGES["common.helpers.validate_order.error_duplicate"]="Duplicate MODULE_ORDER (%s): %s"
I18N_MESSAGES["common.delete.error"]="Error deleting: %s"
I18N_MESSAGES["common.delete.success"]="Deleted: %s"
I18N_MESSAGES["common.helpers.ssh.no_active_ports"]="No active SSH ports [ss -ltnp]"
I18N_MESSAGES["common.helpers.ssh.active_ports"]="Active SSH ports found [ss -ltnp]: %s"
I18N_MESSAGES["common.helpers.ufw.rules_found"]="UFW rules found [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules_not_found"]="No UFW rules [ufw show added]"
I18N_MESSAGES["common.helpers.ufw.rules.sync"]="UFW rules synchronized with ${UTIL_NAME^^} settings for SSH port"
I18N_MESSAGES["common.helpers.ufw.rules.delete_warning"]="Deleting SSH rules will also delete related UFW rules"
I18N_MESSAGES["common.helpers.ufw.rule.deleted"]="Deleted UFW rule: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.delete_error"]="Error deleting UFW rule: ufw --force delete %s"
I18N_MESSAGES["common.helpers.ufw.rule.added"]="Created UFW rule: [ufw allow %s/tcp comment '$BSSS_MARKER_COMMENT]'"
I18N_MESSAGES["common.helpers.ufw.rule.add_error"]="Error adding UFW rule: [ufw allow %s/tcp comment ${UTIL_NAME^^}]"
I18N_MESSAGES["common.helpers.ufw.disabled"]="UFW: Fully deactivated [ufw --force disable]"
I18N_MESSAGES["common.helpers.ufw.already_disabled"]="UFW: deactivated"
I18N_MESSAGES["common.helpers.rollback.stop_signal"]="Sending rollback disable signal USR1 [PID: %s]"
I18N_MESSAGES["common.helpers.rollback.stop_received"]="Received USR1 signal - stopping script due to rollback"
I18N_MESSAGES["common.helpers.rollback.fifo_created"]="Created FIFO: %s"

# Exit signals
I18N_MESSAGES["common.helpers.rollback.exit_received"]="Received EXIT signal [RC: %s]"
I18N_MESSAGES["common.helpers.rollback.int_received"]="Received INT signal [RC: %s]"

# Init helpers

# UFW check
I18N_MESSAGES["ufw.check.installed_restart"]="UFW installed - restart the script"

# OS check
I18N_MESSAGES["os.check.file_not_found"]="File does not exist: %s"
I18N_MESSAGES["os.check.unsupported"]="System %s not supported (expected: %s)"
I18N_MESSAGES["os.check.supported"]="System %s supported"
