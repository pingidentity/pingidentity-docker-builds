#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script handles removing the server from the topology during a shutdown.
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# Sync servers before 8.2.0.0-EA will not have failover configured.
if ! is_ge_82; then
    exit 0
fi

# Run remove-defunct-server
removeDefunctServer
