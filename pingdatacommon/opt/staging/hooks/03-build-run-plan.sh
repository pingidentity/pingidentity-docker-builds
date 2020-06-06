#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This scrip is called to check if there is an existing server
#- and if so, it will return a 1, else 0
#

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

RUN_PLAN="UNKNOWN"

SERVER_UUID_FILE="${SERVER_ROOT_DIR}/config/server.uuid"

if  test -f "${SERVER_UUID_FILE}" ; then
    . "${SERVER_UUID_FILE}"

    RUN_PLAN="RESTART"
else
    RUN_PLAN="START"
fi

INSTANCE_NAME="$(hostname)"

# next line is for shellcheck disable to ensure $RUN_PLAN is used
echo "${RUN_PLAN} ${INSTANCE_NAME}" >> /dev/null

echo_header "Run Plan Information"
echo_vars RUN_PLAN INSTANCE_NAME serverUUID
echo_bar

export_container_env RUN_PLAN INSTANCE_NAME
