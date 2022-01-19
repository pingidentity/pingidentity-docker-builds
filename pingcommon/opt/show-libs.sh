#!/usr/bin/env sh
# shellcheck disable=SC1091
. "${HOOKS_DIR}/pingcommon.lib.sh"
show_libs_ver "${1:-log4j}"
