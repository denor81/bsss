#!/usr/bin/env bash
# MODULE_TYPE: helper
# Использование: source "/modules/...sh"

# @stdout:      # x 80
_draw_border() {
    printf '%.0s#' {1..80} >&2; echo >&2
}