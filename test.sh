#!/usr/bin/env bash
readonly SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
echo "${BASH_SOURCE[@]}"
echo "${BASH_SOURCE[0]}"
echo "$(readlink -f "${BASH_SOURCE[0]}")"
echo "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )"
echo "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"
echo "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)"