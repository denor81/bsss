# UFW messages (English)
declare -gA I18N_MESSAGES

# Menu UI
I18N_MESSAGES["ufw.menu.display.available_actions"]="Available actions:"
I18N_MESSAGES["ufw.menu.display.no_rules"]="No BSSS rules, but UFW is active - can be disabled"
I18N_MESSAGES["ufw.menu.display.exit"]="Exit"

# Info messages
I18N_MESSAGES["ufw.info.enabled"]="UFW is enabled"
I18N_MESSAGES["ufw.info.disabled"]="UFW is disabled"
I18N_MESSAGES["ufw.info.ping_blocked"]="UFW ping blocked [DROP] [Status: modified]"
I18N_MESSAGES["ufw.info.ping_allowed"]="UFW ping allowed [ACCEPT] [Status: default]"

# Error messages
I18N_MESSAGES["ufw.error.enable_failed"]="Error during activation [ufw --force enable]"
I18N_MESSAGES["ufw.error.disable_failed"]="Error during deactivation [ufw --force disable]"

# Success messages
I18N_MESSAGES["ufw.success.backup_created"]="Backup created: [%s]"
I18N_MESSAGES["ufw.success.backup_failed"]="Failed to create backup %s [%s]"
I18N_MESSAGES["ufw.success.before_rules_edited"]="Edited: [%s]"
I18N_MESSAGES["ufw.success.before_rules_restore_failed"]="Error during editing: [%s]"
I18N_MESSAGES["ufw.success.rules_deleted"]="BSSS rules deleted"
I18N_MESSAGES["ufw.success.reloaded"]="UFW reloaded [ufw reload]"

# Warning messages
I18N_MESSAGES["ufw.warning.backup_not_found"]="Backup not found"
