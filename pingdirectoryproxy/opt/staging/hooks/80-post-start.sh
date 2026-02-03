#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is mostly the same as the 80-post-start.sh hook in the
#  pingdirectory product image, but configures proxy automatic server discovery rather than
#  configuring replication.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# This hook is only needed when joining a PD topology for automatic server discovery
if test "$(toLower "${JOIN_PD_TOPOLOGY}")" != "true"; then
    exit 0
fi

if ! prepareToJoinTopology; then
    echo "Automatic server discovery for PingDirectoryProxy will not be configured."
    set_server_available online

    exit 0
fi

_podName=$(getHostName)
echo "Waiting until ${PING_PRODUCT} service is running on this Server (${POD_HOSTNAME:?})"
echo "        ${_podName:?}:${POD_LDAPS_PORT:?}"

waitUntilLdapUp "${_podName}" "${POD_LDAPS_PORT}" ""

#
#- * Enabling PingDirectoryProxy Automatic Server Discovery
#
printf "
#############################################
# Enabling PingDirectoryProxy Automatic Server Discovery
#
#   %60s        %-60s
#   %60s  <-->  %-60s
#############################################
" "Topology PingDirectory Server" "POD Server" "${PINGDIRECTORY_HOSTNAME}:${PINGDIRECTORY_LDAPS_PORT}" "${POD_HOSTNAME}:${POD_LDAPS_PORT:?}"

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
    --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --ignoreWarnings

_addServerResult=$?
test "${VERBOSE}" != "true" && set +x
echo "Automatic server discovery configuration for POD Server result=${_addServerResult}"

if test ${_addServerResult} -ne 0; then
    echo "Failed to configure Proxy automatic server discovery."
else
    set_server_available online
fi

exit ${_addServerResult}
