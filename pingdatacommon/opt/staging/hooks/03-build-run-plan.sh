#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is called to check if there is an existing server
#- and if so, it will return a 1, else 0
#

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

RUN_PLAN="UNKNOWN"

SERVER_UUID_FILE="${SERVER_ROOT_DIR}/config/server.uuid"

if test -f "${SERVER_UUID_FILE}"; then
    RUN_PLAN="RESTART"
else
    RUN_PLAN="START"
fi

INSTANCE_NAME=$(getPingDataInstanceName)

# next line is for shellcheck disable to ensure $RUN_PLAN is used
echo "${RUN_PLAN} ${INSTANCE_NAME}" >> /dev/null

echo_header "Run Plan Information"
echo_vars RUN_PLAN INSTANCE_NAME serverUUID
echo_bar

export_container_env RUN_PLAN INSTANCE_NAME
