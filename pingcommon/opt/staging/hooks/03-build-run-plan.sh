#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script will building a run plan for the server as it starts up
#- Options for the RUN_PLAN and the PD_STATE are as follows:
#-
#- RUN_PLAN (Initially set to UNKNOWN)
#-          START   - Instructs the container to start from scratch.  This is primarily
#-                    because a SERVER_ROOT_DIR (i.e. /opt/out/instance) isn't preseent.
#-          RESTART - Instructs the container to restart.  This is primarily because the
#-                    SERVER_ROOT_DIR (i.e. /opt/out/instance) is prsent.
#-
#- > NOTE: It will be common for products to override this hook to provide
#- > RUN_PLAN directions based on product specifics.

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#
# Check for the existence of a SERVER_ROOT_DIR
#   If NOT Found, then we are STARTing for the first time
#   If Found,     then we are RESTARTing
#
if test -d "${SERVER_ROOT_DIR}"
then
    echo "Found SERVER_ROOT: ${SERVER_ROOT_DIR}"
    RUN_PLAN="RESTART"
else
    echo "Missing SERVER_ROOT: ${SERVER_ROOT_DIR}"
    RUN_PLAN="START"
fi

# next line is for shellcheck disable to ensure $RUN_PLAN is used
echo ${RUN_PLAN} >> /dev/null

echo_header "Run Plan Information"
echo_vars RUN_PLAN
echo_bar

export_container_env RUN_PLAN