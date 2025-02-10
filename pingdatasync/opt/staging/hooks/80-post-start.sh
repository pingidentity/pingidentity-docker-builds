#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is mostly the same as the 80-post-start.sh hook in the
#  pingdirectory product image, but configures sync failover rather than
#  configuring replication.
#
test "${VERBOSE}" = "true" && set -x

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
#   %60s        %-60s
#   %60s  <-->  %-60s
#############################################
" "Remote Server" "POD Server" "${REMOTE_SERVER_HOSTNAME}:${REMOTE_SERVER_LDAPS_PORT}" "${POD_HOSTNAME}:${POD_LDAPS_PORT:?}"

set -x
manage-topology add-server \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --hostname "${REMOTE_SERVER_HOSTNAME}" \
    --port "${REMOTE_SERVER_LDAPS_PORT}" \
    --useSSL \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --remoteServerHostname "${POD_HOSTNAME}" \
    --remoteServerPort "${POD_LDAPS_PORT}" \
    --remoteServerConnectionSecurity useSSL \
    --remoteServerBindDN "${ROOT_USER_DN}" \
    --remoteServerBindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --ignoreWarnings

_addServerResult=$?
test "${VERBOSE}" != "true" && set +x
echo "Failover configuration for POD Server result=${_addServerResult}"

if test ${_addServerResult} -ne 0; then
    echo "Failed to configure sync failover."
fi

exit ${_addServerResult}
