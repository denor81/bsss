# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

# @type:        Validator
# @description: Requires grep to report no matches, rejecting matches and execution errors
# @params:      args Grep pattern and file paths (array), without terminators
# @stdin:       None
# @stdout:      None
# @exit_code:   0 no matches
#               1 a match was found or grep failed
test::assert::no_match() {
    if grep -q "$@"; then
        return 1
    else
        [[ $? == 1 ]]
    fi
}
