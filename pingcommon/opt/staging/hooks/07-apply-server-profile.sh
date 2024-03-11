#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- The server-profiles from:
#-
#- * remote (i.e. git) and
#- * local (i.e. /opt/in)
#-
#- have been merged into the ${STAGING_DIR}/instance (ie. /opt/staging/instance).
#-
#- This is a candidate to be installed or overwritten into the ${SERVER_ROOT_DIR}
#- if one of the following items are true:
#-
#- * Start of a new server (i.e. RUN_PLAN=START)
#- * Restart of a server with SERVER_PROFILE_UPDATE==true
#-
#- To force the overwrite of files on a restart, ensure that the variable:
#-
#-     SERVER_PROFILE_UPDATE=true
#-
#- is passed.

#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# Check to see if there there is an instance directory and files in it
if test -d "${STAGING_DIR}/instance" && test -n "$(ls -A "${STAGING_DIR}/instance")"; then
    # If this is a new server or the a SERVER_PROFILE_UPDATE is asked for
    # Then copy/overwrite files to SERVER_ROOT_DIR
    if test "${RUN_PLAN}" = "START" || test "${SERVER_PROFILE_UPDATE}" = "true"; then
        echo "merging ${STAGING_DIR}/instance to ${SERVER_ROOT_DIR}"
        copy_files "${STAGING_DIR}/instance" "${SERVER_ROOT_DIR}"
    else
        echo "no merge requested from ${STAGING_DIR}/instance to ${SERVER_ROOT_DIR} (SERVER_PROFILE_UPDATE=${SERVER_PROFILE_UPDATE})"
    fi
fi
