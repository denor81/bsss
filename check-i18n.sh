#!/usr/bin/env bash
#
# Quick i18n check wrapper for pre-commit hooks
# Returns non-zero if translation issues found

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CHECK_SCRIPT="${SCRIPT_DIR}/lib/i18n/check_translations.sh"

if [[ ! -x "$CHECK_SCRIPT" ]]; then
    chmod +x "$CHECK_SCRIPT"
fi

# Run the check
if bash "$CHECK_SCRIPT" 2>&1 | tee /dev/tty; then
    exit 0
else
    exit 1
fi
