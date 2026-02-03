# UFW messages (English)
declare -gA UFW_MESSAGES

# Menu UI
UFW_MESSAGES["ufw.menu.display.available_actions"]="Available actions:"
UFW_MESSAGES["ufw.menu.display.no_rules"]="No BSSS rules, but UFW is active - can be disabled"
UFW_MESSAGES["ufw.menu.display.exit"]="Exit"

# Info messages
UFW_MESSAGES["ufw.info.enabled"]="UFW is enabled"
UFW_MESSAGES["ufw.info.disabled"]="UFW is disabled"
UFW_MESSAGES["ufw.info.ping_blocked"]="UFW ping blocked [DROP] [Status: modified]"
UFW_MESSAGES["ufw.info.ping_allowed"]="UFW ping allowed [ACCEPT] [Status: default]"

# Error messages
UFW_MESSAGES["ufw.error.enable_failed"]="Error during activation [ufw --force enable]"
UFW_MESSAGES["ufw.error.disable_failed"]="Error during deactivation [ufw --force disable]"

# Success messages
UFW_MESSAGES["ufw.success.backup_created"]="Backup created: [%s]"
UFW_MESSAGES["ufw.success.backup_failed"]="Failed to create backup %s [%s]"
UFW_MESSAGES["ufw.success.before_rules_edited"]="Edited: [%s]"
UFW_MESSAGES["ufw.success.before_rules_restore_failed"]="Error during editing: [%s]"
UFW_MESSAGES["ufw.success.rules_deleted"]="BSSS rules deleted"
UFW_MESSAGES["ufw.success.reloaded"]="UFW reloaded [ufw reload]"

# Warning messages
UFW_MESSAGES["ufw.warning.backup_not_found"]="Backup not found"
