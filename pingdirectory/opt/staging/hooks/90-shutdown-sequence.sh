#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script handles removing the server from the topology during a shutdown.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=./pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

if test "$(toLower "${SKIP_SHUTDOWN_SEQUENCE}")" = "true"; then
    echo "SKIP_SHUTDOWN_SEQUENCE environment variable set to true, exiting"
    exit 0
fi

# Check for a marker file indicating that this server is the seed server
if test -f /tmp/seed-server; then
    echo "remove-defunct-server will not be run on shutdown, since this server is the seed server."
else
    echo "Running remove-defunct-server on shutdown."
    removeDefunctServer
fi
