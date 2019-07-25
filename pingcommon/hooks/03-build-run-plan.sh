#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This scrip is called to check if there is an existing server
#- and if so, it will return a 1, else 0
#

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

rm -rf "${STATE_PROPERTIES}"

RUN_PLAN="UNKNOWN"

if test -d "${SERVER_ROOT_DIR}" ; then
    echo "Found SERVER_ROOT: ${SERVER_ROOT_DIR}"
    RUN_PLAN="RESTART"
else
    echo "Missing SERVER_ROOT: ${SERVER_ROOT_DIR}"
    RUN_PLAN="START"
fi

echo_header "
###################################################################################
#                      RUN_PLAN: ${RUN_PLAN}
###################################################################################
" >"${STATE_PROPERTIES}"

# Display the new state properties
cat "${STATE_PROPERTIES}"

echo "
RUN_PLAN=${RUN_PLAN}
" >> "${STATE_PROPERTIES}"