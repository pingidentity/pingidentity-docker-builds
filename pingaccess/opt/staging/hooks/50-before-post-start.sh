#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This is called after the start or restart sequence has finished and before 
#- the server within the container starts
#

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

echo "INFO: OPERATIONAL_MODE: ${OPERATIONAL_MODE}"
if test -n "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"
then
    echo "INFO: Shutting down the eth01 interface..."
    ip link set eth0 down
fi

if test -n "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE" 
then
    echo "INFO: Adding engine..."
    run_hook "51-add-engine.sh"
fi