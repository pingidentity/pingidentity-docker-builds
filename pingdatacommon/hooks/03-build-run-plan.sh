#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This scrip is called to check if there is an existing server
#- and if so, it will return a 1, else 0
#

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

rm -rf "${STATE_PROPERTIES}"

RUN_PLAN="UNKNOWN"

SERVER_UUID_FILE="${SERVER_ROOT_DIR}/config/server.uuid"

if  test -f "${SERVER_UUID_FILE}" ; then
    . "${SERVER_UUID_FILE}"
    
    RUN_PLAN="RESTART"
else
    RUN_PLAN="START"
fi

echo "
###################################################################################
#                      RUN_PLAN: ${RUN_PLAN}
###################################################################################
" >> "${STATE_PROPERTIES}"

# Display the new state properties
cat "${STATE_PROPERTIES}"

echo "
RUN_PLAN=${RUN_PLAN}
" >> "${STATE_PROPERTIES}"