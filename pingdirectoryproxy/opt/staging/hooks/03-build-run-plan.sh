#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is called to determine the plan for the server as it starts up.
#

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

test "${VERBOSE}" = "true" && set -x

# Set run plan defaults
RUN_PLAN="UNKNOWN"

SERVER_UUID_FILE="${SERVER_ROOT_DIR}/config/server.uuid"

# Ignore shellcheck SC2034 here because shellcheck sees these variables as unused. The values
# are passed in to export_container_env below.

if test -f "${SERVER_UUID_FILE}"; then
    RUN_PLAN="RESTART"
else
    # shellcheck disable=SC2034
    RUN_PLAN="START"
fi

# shellcheck disable=SC2034
INSTANCE_NAME=$(getPingDataInstanceName)

echo_header "Run Plan Information"
echo_vars RUN_PLAN INSTANCE_NAME serverUUID
echo_bar

export_container_env RUN_PLAN INSTANCE_NAME

# Only need to set run plan when joining a PingDirectory topology
if test "$(toLower "${JOIN_PD_TOPOLOGY}")" != "true"; then
    echo "Backend discovery for PingDirectoryProxy will not be configured, because JOIN_PD_TOPOLOGY is not set to true."
    exit 0
fi

if test -z "${PINGDIRECTORY_HOSTNAME}" ||
    test -z "${PINGDIRECTORY_LDAPS_PORT}"; then
    container_failure 3 "One of PINGDIRECTORY_HOSTNAME: (${PINGDIRECTORY_HOSTNAME}), PINGDIRECTORY_LDAPS_PORT: (${PINGDIRECTORY_LDAPS_PORT}) aren't set. These variables must be set when JOIN_PD_TOPOLOGY is true."
fi

buildRunPlan
