#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook configures pingdirectory replication
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck source=./pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

# Check availability and set variables necessary for enabling replication
# If this method returns a non-zero exit code, then we shouldn't try
# to enable replication
if ! prepareToJoinTopology; then
    echo "Replication will not be configured."
    set_server_available online

    exit 0
fi

set_server_unavailable "Enabling replication" online

#
#- * Enabling Replication
#
printf "
#############################################
# Enabling Replication
#
# Current Master Topology Instance: ${MASTER_TOPOLOGY_INSTANCE}
#
#   %60s        %-60s
#   %60s  <-->  %-60s
#############################################
" "Topology Master Server" "POD Server" "${MASTER_TOPOLOGY_HOSTNAME}:${MASTER_TOPOLOGY_LDAPS_PORT}" "${POD_HOSTNAME}:${_podReplicationPort:?}"

# Use positional arguments to build --baseDN args for dsreplication
set -- --baseDN "${USER_BASE_DN}"
if test -n "${REPLICATION_BASE_DNS}"; then
    while test "${REPLICATION_BASE_DNS}" != "${_iter}"; do
        # Extract the base DN from start of string up to ';' delimiter.
        _iter=${REPLICATION_BASE_DNS%%;*}
        # Delete the first base DN and the ';' from REPLICATION_BASE_DNS
        REPLICATION_BASE_DNS="${REPLICATION_BASE_DNS#"${_iter}";}"
        # Add the --baseDN argument for the extracted base DN
        set -- "$@" --baseDN "${_iter}"
    done
fi

dsreplication enable \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --host1 "${MASTER_TOPOLOGY_HOSTNAME}" \
    --port1 "${MASTER_TOPOLOGY_LDAPS_PORT}" \
    --useSSL1 \
    --replicationPort1 "${MASTER_TOPOLOGY_REPLICATION_PORT}" \
    --bindDN1 "${ROOT_USER_DN}" \
    --bindPasswordFile1 "${ROOT_USER_PASSWORD_FILE}" \
    \
    --host2 "${POD_HOSTNAME}" \
    --port2 "${POD_LDAPS_PORT}" \
    --useSSL2 \
    --replicationPort2 "${_podReplicationPort}" \
    --bindDN2 "${ROOT_USER_DN}" \
    --bindPasswordFile2 "${ROOT_USER_PASSWORD_FILE}" \
    \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --no-prompt --ignoreWarnings \
    "$@" \
    --noSchemaReplication \
    --enableDebug --globalDebugLevel verbose

_replEnableResult=$?
echo "Replication enable for POD Server result=${_replEnableResult}"

if test ${_replEnableResult} -ne 0; then
    echo "Not running dsreplication initialize since enable failed with a non-successful return code"
    exit ${_replEnableResult}
fi

#
#- * Get the new current topology
#
echo "Getting Topology from SEED Server"
rm -rf "${TOPOLOGY_FILE}"
manage-topology export \
    --hostname "${SEED_HOSTNAME}" \
    --port "${SEED_LDAPS_PORT}" \
    --exportFilePath "${TOPOLOGY_FILE}"

cat "${TOPOLOGY_FILE}"

set_server_unavailable "Initializing replication" online

#
#- * Initialize replication
#
echo "Initializing replication on POD Server"
dsreplication initialize \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    \
    --topologyFilePath "${TOPOLOGY_FILE}" \
    \
    --hostDestination "${POD_HOSTNAME}" --portDestination "${POD_LDAPS_PORT}" --useSSLDestination \
    \
    "$@" \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --no-prompt \
    --enableDebug \
    --globalDebugLevel verbose

_replInitResult=$?
echo "Replication initialize result=${_replInitResult}"

test ${_replInitResult} -eq 0 && set_server_available online && dsreplication status --displayServerTable --showAll

exit ${_replInitResult}
