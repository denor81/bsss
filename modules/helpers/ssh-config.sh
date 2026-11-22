# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Checks that the standard SSH drop-in include precedes managed settings
# @stdin:       None
# @stdout:      None
# @exit_code:   0 supported include found
#               1 include missing, late, or configuration object unsupported
ssh::config::standard_include_is_early() {
    [[ -f "$SSH_CONFIG_FILE" && ! -L "$SSH_CONFIG_FILE" && -r "$SSH_CONFIG_FILE" ]] ||
        return 1

    gawk -v expected="${SSH_CONFIGD_DIR}/*.conf" '
        BEGIN {
            IGNORECASE = 1
        }
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            if (line == "" || line ~ /^#/) {
                next
            }
            count = split(line, fields, /[[:space:]]+/)
            key = tolower(fields[1])
            if (key == "match") {
                in_match = 1
                next
            }
            if (in_match) {
                next
            }
            if (key == "include") {
                for (i = 2; i <= count; i++) {
                    if (fields[i] == expected && !managed_before) {
                        include_found = 1
                    }
                }
                next
            }
            if (key ~ /^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication|challengeresponseauthentication)$/ &&
                !include_found) {
                managed_before = 1
            }
        }
        END {
            exit (include_found && !managed_before) ? 0 : 1
        }
    ' "$SSH_CONFIG_FILE"
}

# @type:        Orchestrator
# @description: Refuses SSH drop-in mutation when the standard include is unavailable
# @stdin:       None
# @stdout:      None
# @exit_code:   0 drop-ins supported
#               1 inspection or guide output failed
#               4 preconfiguration required
ssh::config::preflight_dropins() {
    if ssh::config::standard_include_is_early; then
        return 0
    fi

    log_warn "$(_ "ssh.preflight.include_missing" "$SSH_CONFIG_FILE")"
    common::preconfiguration::show || return 1
    return 4
}
