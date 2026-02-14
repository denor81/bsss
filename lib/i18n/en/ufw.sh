# UFW messages (English)

# Modify messages
I18N_MESSAGES["ufw.modify.confirm"]="Modify UFW status?"

# Error messages
I18N_MESSAGES["ufw.error.enable_failed"]="Error during activation [ufw --force enable]"

# Success messages
I18N_MESSAGES["ufw.success.backup_created"]="Backup created: [%s]"
I18N_MESSAGES["ufw.error.backup_failed"]="Failed to create backup %s [%s]"
I18N_MESSAGES["ufw.success.before_rules_edited"]="Edited: [%s]"
I18N_MESSAGES["ufw.success.reloaded"]="UFW reloaded [ufw reload]"
I18N_MESSAGES["ufw.warning.continue_without_rules"]="Cannot continue: no BSSS rules in UFW"
I18N_MESSAGES["ufw.warning.add_ssh_first"]="First add SSH port via SSH module"
I18N_MESSAGES["ufw.rollback.warning_title"]="DO NOT CLOSE THIS TERMINAL WINDOW"
I18N_MESSAGES["ufw.rollback.test_access"]="Check server access after enabling UFW in a new terminal window"

# Menu messages
I18N_MESSAGES["ufw.menu.item_disable"]="Disable UFW"
I18N_MESSAGES["ufw.menu.item_enable"]="Enable UFW"
I18N_MESSAGES["ufw.menu.item_ping_enable"]="Ping will be enabled [ACCEPT] [Default]"
I18N_MESSAGES["ufw.menu.item_ping_disable"]="Ping will be disabled [DROP]"

# Status messages
I18N_MESSAGES["ufw.status.enabled"]="UFW enabled"
I18N_MESSAGES["ufw.status.disabled"]="UFW disabled"
I18N_MESSAGES["ufw.status.ping_blocked"]="UFW ping blocked [DROP] [Status: modified]"
I18N_MESSAGES["ufw.status.ping_allowed"]="UFW ping allowed [ACCEPT] [Status: default]"

# Info messages
I18N_MESSAGES["ufw.info.no_rules_but_active"]="No BSSS rules, but UFW is active - can be disabled"

# Success messages
I18N_MESSAGES["ufw.success.enabled"]="UFW: Activated [ufw --force enable]"
I18N_MESSAGES["ufw.success.icmp_changed"]="ICMP rules changed to DROP"
I18N_MESSAGES["ufw.success.backup_restored"]="before.rules file restored: [%s]"

# Error messages
I18N_MESSAGES["ufw.error.invalid_menu_id"]="Invalid action ID: [%s]"
I18N_MESSAGES["ufw.error.backup_failed"]="Failed to create backup %s [%s]"
I18N_MESSAGES["ufw.error.restore_failed"]="Failed to restore %s from backup [%s]"
I18N_MESSAGES["ufw.error.edit_failed"]="Error during editing: [%s]"
I18N_MESSAGES["ufw.error.reload_failed"]="Failed to execute [ufw reload] [RC: %s]"
