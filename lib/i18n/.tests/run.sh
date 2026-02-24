#!/usr/bin/env bash
# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT
# Запускает все тесты в текущей директории

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

for test_file in *.sh; do
    [[ "$test_file" == "run.sh" ]] && continue
    printf '%s\n' "$test_file"
    bash "$test_file"
    printf '%s\n' "$(printf '#%.0s' {1..80})"
done
