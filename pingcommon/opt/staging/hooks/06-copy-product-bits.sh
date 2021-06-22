#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Copies the server bits from the image into the SERVER_ROOT_DIR if
#- it is a new fresh container.
#

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# Applies the RAW Server Bits from the built images into SERVER_ROOT
if test "${RUN_PLAN}" = "START"; then
    echo "Copying SERVER_BITS_DIR (${SERVER_BITS_DIR}) to SERVER_ROOT_DIR (${SERVER_ROOT_DIR})"
    mkdir -p "${SERVER_ROOT_DIR}"
    cp -Rf "${SERVER_BITS_DIR}/"* "${SERVER_ROOT_DIR}/"
fi
