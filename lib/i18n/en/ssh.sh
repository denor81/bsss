# SSH port messages (English)
declare -gA SSH_MESSAGES

# Menu UI
SSH_MESSAGES["ssh.ui.get_action_choice.available_actions"]="Available actions:"
SSH_MESSAGES["ssh.ui.get_action_choice.option_reset"]="Reset (delete ${UTIL_NAME^^} rule)"
SSH_MESSAGES["ssh.ui.get_action_choice.option_reinstall"]="Reinstall (replace with new port)"
SSH_MESSAGES["ssh.ui.get_action_choice.option_exit"]="Exit"
SSH_MESSAGES["ssh.ui.get_action_choice.ask_select"]="Select action"
SSH_MESSAGES["ssh.ui.get_action_choice.hint"]="Select number from 0 to 2"

# Input prompts
SSH_MESSAGES["ssh.ui.get_new_port.ask_port"]="Enter new SSH port"
SSH_MESSAGES["ssh.ui.get_new_port.hint"]="Port must be from 1 to 65535"
SSH_MESSAGES["ssh.ui.get_new_port.default"]="22"

# Info messages
SSH_MESSAGES["ssh.info_rules_found"]="${UTIL_NAME^^} rules found for SSH:"
SSH_MESSAGES["ssh.info_no_rules"]="No ${UTIL_NAME^^} rules for SSH [%s]"

# Success messages
SSH_MESSAGES["ssh.success_port_up"]="SSH port %s successfully raised after %s attempts in %s sec"
SSH_MESSAGES["ssh.success_rule_created"]="${UTIL_NAME^^} rule created for SSH: [%s:%s]"
SSH_MESSAGES["ssh.success_changes_committed"]="Changes committed, Rollback disabled"

# Error messages
SSH_MESSAGES["ssh.error_port_busy"]="SSH port %s is already in use by another service."
SSH_MESSAGES["ssh.error_rule_creation_failed"]="Failed to create SSH rule: %s"
SSH_MESSAGES["ssh.error_config_sshd"]="SSH config error [sshd -t]"

# Warning messages
SSH_MESSAGES["ssh.warning_external_rules_found"]="External SSH rules found:"
SSH_MESSAGES["ssh.warning_no_external_rules"]="No external SSH rules [%s]"
