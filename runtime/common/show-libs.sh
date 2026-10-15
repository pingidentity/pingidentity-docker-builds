#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

# shellcheck disable=SC1091
. "${HOOKS_DIR}/pingcommon.lib.sh"
show_libs_ver "${1:-log4j}"
