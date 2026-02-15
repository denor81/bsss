#!/usr/bin/env bash
# Проверяет проект на забытые захардкоженные строки

set -Eeuo pipefail

readonly PROJECT_ROOT=$(readlink -f "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/../../..")

FUNC_NAMES="log_info_simple_tab|log_attention|log_warn|log_bold_info|log_info|log_error|log_success"

echo "These strings might need localization using the _() function."
echo "Review the output below and decide if each case requires translation."
echo

grep -rnE "($FUNC_NAMES)\s+\"[^\"]+\"" --include="*.sh" "$PROJECT_ROOT" \
| grep -vE '"(\$|.*[^"]\$\(_)' \
| sed 's/:[[:space:]]*/:/g' || echo "No strings found"