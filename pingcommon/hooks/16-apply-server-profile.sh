#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Once both the remote (i.e. git) and local server-profiles have been merged
#- then we can push that out to the instance.  This will override any files found
#- in the ${OUT_DIR}/instance directory.
#
${VERBOSE} && set -x

# shellcheck source=../lib.sh
. "${BASE}/lib.sh"

if test -d "${STAGING_DIR}/instance" ; then
    echo "merging ${STAGING_DIR}/instance to ${OUT_DIR}/instance"
    cp -af "${STAGING_DIR}/instance" "${OUT_DIR}"
fi

