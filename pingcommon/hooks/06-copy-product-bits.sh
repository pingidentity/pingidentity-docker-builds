#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Copies the server bits from the image into the SERVER_ROOT_DIR if we a
#- new fresh container is started
#

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# Applies the RAW Server Bits from the built images into SERVER_ROOT
if test "${RUN_PLAN}" == "START" ; then
    echo "Copying product bits to SERVER_ROOT"
    cp -af "${SERVER_BITS_DIR}" "${SERVER_ROOT_DIR}"
fi
