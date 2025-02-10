#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script will building a run plan for the server as it starts up
#- Options for the RUN_PLAN and the PD_STATE are as follows:
#-
#- RUN_PLAN (Initially set to UNKNOWN)
#-          START   - Instructs the container to start from scratch.  This is primarily
#-                    because a STARTUP_COMMAND (i.e. /opt/out/instance/bin/run.sh) isn't present.
#-          RESTART - Instructs the container to restart.  This is primarily because the
#-                    STARTUP_COMMAND (i.e. /opt/out/instance/bin/run.sh) is present and typically
#-                    signifies that the server bits have been copied and run before
#-
#- > NOTE: It will be common for products to override this hook to provide
#- > RUN_PLAN directions based on product specifics.

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#
# Check for the existence of a STARTUP_COMMAND
#   If NOT Found, then we are STARTing for the first time
#   If Found,     then we are RESTARTing
#
if test -f "${STARTUP_COMMAND}"; then
    RUN_PLAN="RESTART"
else
    RUN_PLAN="START"
fi

# next line is for shellcheck disable to ensure $RUN_PLAN is used
echo ${RUN_PLAN} >> /dev/null

echo_header "Run Plan Information"
echo_vars RUN_PLAN
echo_bar

export_container_env RUN_PLAN
