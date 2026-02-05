#!/usr/bin/env bash
# Запускает все тесты в текущей директории

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

for test_file in *.sh; do
    [[ "$test_file" == "run.sh" ]] && continue
    
    bash "$test_file"
    printf '%s\n\n' "$(printf '#%.0s' {1..80})"
done
