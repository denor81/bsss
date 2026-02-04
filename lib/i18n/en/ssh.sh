# SSH port messages (English)

# Modify messages
I18N_MESSAGES["ssh.modify.confirm"]="Modify SSH port configuration?"

# Menu UI
I18N_MESSAGES["ssh.ui.get_action_choice.available_actions"]="Available actions:"
I18N_MESSAGES["ssh.ui.get_action_choice.option_reset"]="Reset (delete ${UTIL_NAME^^} rule)"
I18N_MESSAGES["ssh.ui.get_action_choice.option_reinstall"]="Reinstall (replace with new port)"
I18N_MESSAGES["ssh.ui.get_action_choice.option_exit"]="Exit"
I18N_MESSAGES["ssh.ui.get_action_choice.ask_select"]="Select action"
I18N_MESSAGES["ssh.ui.get_action_choice.hint"]="Select number from 0 to 2"

# Input prompts
I18N_MESSAGES["ssh.ui.get_new_port.ask_port"]="Enter new SSH port"
I18N_MESSAGES["ssh.ui.get_new_port.hint"]="Port must be from 1 to 65535"
I18N_MESSAGES["ssh.ui.get_new_port.default"]="22"
I18N_MESSAGES["ssh.ui.get_action_choice.ask_select"]="Select"
I18N_MESSAGES["ssh.install.confirm_connection"]="Confirm connection - enter connected"

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
I18N_MESSAGES["ssh.menu.item_exit"]="%s. Exit"

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
