#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

exit 0
