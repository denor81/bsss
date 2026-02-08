# SSH port messages (English)

# Modify messages
I18N_MESSAGES["ssh.modify.confirm"]="Modify SSH port configuration?"

# Menu UI
I18N_MESSAGES["ssh.ui.get_action_choice.ask_select"]="Select action"

# Input prompts
I18N_MESSAGES["ssh.install.confirm_connection"]="Confirm connection - enter connected or 0 to cancel"

# Info messages
I18N_MESSAGES["ssh.info_rules_found"]="${UTIL_NAME^^} rules found for SSH:"
I18N_MESSAGES["ssh.info_no_rules"]="No ${UTIL_NAME^^} rules for SSH [%s]"

# Success messages
I18N_MESSAGES["ssh.success_port_up"]="SSH port %s successfully raised after %s attempts in %s sec"
I18N_MESSAGES["ssh.success_rule_created"]="${UTIL_NAME^^} rule created for SSH: [%s:%s]"
I18N_MESSAGES["ssh.success_changes_committed"]="Changes committed, Rollback disabled"

# Error messages
I18N_MESSAGES["ssh.error_port_busy"]="SSH port %s is already in use by another service."
I18N_MESSAGES["ssh.error_rule_creation_failed"]="Failed to create SSH rule: %s"
I18N_MESSAGES["ssh.error_config_sshd"]="SSH config error [sshd -t]"
I18N_MESSAGES["ssh.socket.unit_not_found"]="ssh.service unit not found in system"
I18N_MESSAGES["ssh.socket.script_purpose"]="This script switches SSH to service mode"

# Warning messages
I18N_MESSAGES["ssh.warning_external_rules_found"]="External SSH rules found:"
I18N_MESSAGES["ssh.warning_no_external_rules"]="No external SSH rules [%s]"

# Wait messages
I18N_MESSAGES["ssh.socket.wait_for_ssh_up.info"]="Waiting for SSH port %s to come up (timeout: %s sec)..."

# Menu items
I18N_MESSAGES["ssh.menu.item_reset"]="%s. Reset (delete %s rule)"
I18N_MESSAGES["ssh.menu.item_reinstall"]="%s. Reinstall (replace with new port)"

# Input messages
I18N_MESSAGES["ssh.ui.get_new_port.prompt"]="Enter new SSH port"
I18N_MESSAGES["ssh.ui.get_new_port.hint_range"]="1-65535, Enter for %s"

# Service messages
I18N_MESSAGES["ssh.service.daemon_reloaded"]="Configuration reloaded [systemctl daemon-reload]"
I18N_MESSAGES["ssh.service.restarted"]="SSH service restarted [systemctl restart ssh.service]"

# Guard instructions
I18N_MESSAGES["ssh.guard.dont_close"]="DO NOT CLOSE THIS TERMINAL WINDOW"
I18N_MESSAGES["ssh.guard.test_new"]="OPEN NEW WINDOW and test connection via port %s"

# Error messages
I18N_MESSAGES["ssh.error_port_not_up"]="PORT %s DID NOT COME UP [%s attempts in %s sec]"
I18N_MESSAGES["ssh.error_invalid_choice"]="Invalid choice"

# Socket check messages
I18N_MESSAGES["ssh.socket.configured"]="SSH properly configured in service mode"
I18N_MESSAGES["ssh.socket.mode_warning"]="SSH is running in socket-based activation mode, which may conflict with port changes via sshd_config"
I18N_MESSAGES["ssh.socket.mode_required"]="SSH needs to be switched to traditional service mode"
I18N_MESSAGES["ssh.socket.switch_confirm"]="Switch SSH to traditional service mode?"
I18N_MESSAGES["ssh.socket.socket_masked"]="ssh.socket is masked"
I18N_MESSAGES["ssh.socket.socket_enabled"]="ssh.socket is enabled - SSH is running in socket-based activation mode"
I18N_MESSAGES["ssh.socket.socket_disabled"]="ssh.socket is disabled"
I18N_MESSAGES["ssh.socket.socket_status"]="ssh.socket status: %s"
I18N_MESSAGES["ssh.socket.not_found_traditional_mode"]="ssh.socket not found - SSH is running in traditional service mode (Ubuntu 20.04 or manually configured)"
