#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script handles removing the server from the topology during a shutdown.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=./pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

removeDefunctServer
