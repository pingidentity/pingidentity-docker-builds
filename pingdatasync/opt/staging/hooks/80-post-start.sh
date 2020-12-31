#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is mostly the same as the 80-post-start.sh hook in the
#  pingdirectory product image, but configures sync failover rather than
#  configuring replication.
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# Check availability and set variables necessary for enabling failover
# If this method returns a non-zero exit code, then we shouldn't try
# to enable failover
if ! prepareToJoinTopology; then
    echo "Failover will not be configured."
    exit 0
fi

#
#- * Enabling PingDataSync failover
#
printf "
#############################################
# Enabling PingDataSync Failover
#
# Current Master Topology Instance: ${_masterTopologyInstance}
#
#   %60s        %-60s
#   %60s  <-->  %-60s
#############################################
" "Topology Master Server" "POD Server" "${_masterTopologyHostname}:${_masterTopologyLdapsPort}" "${_podHostname}:${_podLdapsPort:?}"

# manage-topology add-server does not currently support an admin password file - see DS-43027
# Read the value from file using get_value if necessary, or default to PING_IDENTITY_PASSWORD.
ADMIN_USER_PASSWORD="$(get_value ADMIN_USER_PASSWORD true)"
if test -z "${ADMIN_USER_PASSWORD}"; then
    ADMIN_USER_PASSWORD="${PING_IDENTITY_PASSWORD}"
fi

manage-topology add-server \
    --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
    --trustAll \
    --hostname "${_masterTopologyHostname}" \
    --port "${_masterTopologyLdapsPort}" \
    --useSSL \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    \
    --remoteServerHostname "${_podHostname}" \
    --remoteServerPort ${_podLdapsPort} \
    --remoteServerConnectionSecurity useSSL \
    --remoteServerBindDN "${ROOT_USER_DN}" \
    --remoteServerBindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPassword "${ADMIN_USER_PASSWORD}" \
    --ignoreWarnings

_addServerResult=$?
echo "Failover configuration for POD Server result=${_addServerResult}"

if test ${_addServerResult} -ne 0; then
    echo "Failed to configure sync failover."
fi

exit ${_addServerResult}