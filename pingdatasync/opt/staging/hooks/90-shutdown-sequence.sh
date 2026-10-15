#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script handles removing the server from the topology during a shutdown.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../runtime/common/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../runtime/pingdata/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# Run remove-defunct-server
removeDefunctServer
