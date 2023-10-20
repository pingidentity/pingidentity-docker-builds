#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is mostly the same as the 80-post-start.sh hook in the
#  pingdirectory product image, but configures proxy automatic backend discovery rather than
#  configuring replication.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# This hook is only needed when joining a PD topology for automatic backend discovery
if test "$(toLower "${JOIN_PD_TOPOLOGY}")" != "true"; then
    exit 0
fi

if ! prepareToJoinTopology; then
    echo "Backend discovery for PingDirectoryProxy will not be configured."
    set_server_available online

    exit 0
fi

_podName=$(getHostName)
echo "Waiting until ${PING_PRODUCT} service is running on this Server (${POD_HOSTNAME:?})"
echo "        ${_podName:?}:${POD_LDAPS_PORT:?}"

waitUntilLdapUp "${_podName}" "${POD_LDAPS_PORT}" ""

#
#- * Enabling PingDirectoryProxy Backend Discovery
#
printf "
#############################################
# Enabling PingDirectoryProxy Backend Discovery
#
#   %60s        %-60s
#   %60s  <-->  %-60s
#############################################
" "Topology PingDirectory Server" "POD Server" "${PINGDIRECTORY_HOSTNAME}:${PINGDIRECTORY_LDAPS_PORT}" "${POD_HOSTNAME}:${POD_LDAPS_PORT:?}"

# manage-topology add-server does not currently support an admin password file - see DS-43027
# Read the value from file using get_value if necessary, or default to PING_IDENTITY_PASSWORD.
ADMIN_USER_PASSWORD="$(get_value ADMIN_USER_PASSWORD true)"
if test -z "${ADMIN_USER_PASSWORD}"; then
    ADMIN_USER_PASSWORD="${PING_IDENTITY_PASSWORD}"
fi

set -x
manage-topology add-server \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --hostname "${POD_HOSTNAME}" \
    --port "${POD_LDAPS_PORT}" \
    --useSSL \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --remoteServerHostname "${PINGDIRECTORY_HOSTNAME}" \
    --remoteServerPort "${PINGDIRECTORY_LDAPS_PORT}" \
    --remoteServerConnectionSecurity useSSL \
    --remoteServerBindDN "${ROOT_USER_DN}" \
    --remoteServerBindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPassword "${ADMIN_USER_PASSWORD}" \
    --ignoreWarnings

_addServerResult=$?
test "${VERBOSE}" != "true" && set +x
echo "Automatic backend discovery configuration for POD Server result=${_addServerResult}"

if test ${_addServerResult} -ne 0; then
    echo "Failed to configure Proxy automatic backend discovery."
else
    set_server_available online
fi

exit ${_addServerResult}
