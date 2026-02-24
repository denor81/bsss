#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Проверяет проект на забытые захардкоженные строки

set -Eeuo pipefail

readonly PROJECT_ROOT=$(readlink -f "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/../../..")

FUNC_NAMES="log_success|log_error|log_info|log_info_no_log|log_question|log_answer|log_debug|log_bold_info|log_warn|log_attention|log_actual_info|log_info_simple_tab|log_start|log_stop"

echo "These strings might need localization using the _() function."
echo "Review the output below and decide if each case requires translation."
echo

grep -rnE "($FUNC_NAMES)\s+\"[^\"]+\"" --include="*.sh" "$PROJECT_ROOT" \
| grep -vE '"(\$|.*[^"]\$\(_)' \
| sed 's/:[[:space:]]*/:/g' || echo "No strings found"