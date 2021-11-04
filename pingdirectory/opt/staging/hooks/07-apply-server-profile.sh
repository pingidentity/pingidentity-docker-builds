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
#- These files will be installed or overwritten into the ${SERVER_ROOT_DIR}.

test "${VERBOSE}" = "true" && set -x

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# Check to see if there there is an instance directory and files in it
if test -d "${STAGING_DIR}/instance" && find "${STAGING_DIR}/instance" -type f | read -r; then
    # If this is a new server, copy/overwrite files to SERVER_ROOT_DIR
    # If this is a restart, then copy to SERVER_BITS_DIR, so that the files
    # are maintained by manage-profile replace-profile.
    if test "${RUN_PLAN}" = "START"; then
        echo "merging ${STAGING_DIR}/instance to ${SERVER_ROOT_DIR}"
        copy_files "${STAGING_DIR}/instance" "${SERVER_ROOT_DIR}"
    elif test "${RUN_PLAN}" = "RESTART"; then
        echo "merging ${STAGING_DIR}/instance to ${SERVER_BITS_DIR}"
        copy_files "${STAGING_DIR}/instance" "${SERVER_BITS_DIR}"
    fi
fi
