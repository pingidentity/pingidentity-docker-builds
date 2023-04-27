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
_baseDNs="${REPLICATION_BASE_DNS}"
_iter=""
if test -n "${_baseDNs}"; then
    while test "${_baseDNs}" != "${_iter}"; do
        # Extract the base DN from start of string up to ';' delimiter.
        _iter=${_baseDNs%%;*}
        # Delete the first base DN and the ';' from REPLICATION_BASE_DNS
        _baseDNs="${_baseDNs#"${_iter}";}"
        # Add the --baseDN argument for the extracted base DN
        set -- "$@" --baseDN "${_iter}"
    done
fi

# Use positional arguments to build --restricted args for dsreplication enable
_iter=""
_restrictedDNs="${RESTRICTED_BASE_DNS}"
if test -n "${_restrictedDNs}"; then
    while test "${_restrictedDNs}" != "${_iter}"; do
        # Extract the DN from start of string up to ';' delimiter.
        _iter=${_restrictedDNs%%;*}
        # Delete the first DN and the ';' from _restrictedDNs
        _restrictedDNs="${_restrictedDNs#"${_iter}";}"
        # Add the --restricted argument for the extracted DN
        set -- "$@" --restricted "${_iter}"
    done
fi

set -x
dsreplication enable \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --host1 "${MASTER_TOPOLOGY_HOSTNAME}" \
    --port1 "${MASTER_TOPOLOGY_LDAPS_PORT}" \
    --useSSL1 \
    --replicationPort1 "${MASTER_TOPOLOGY_REPLICATION_PORT}" \
    --bindDN1 "${ROOT_USER_DN}" \
    --bindPasswordFile1 "${ROOT_USER_PASSWORD_FILE}" \
    --host2 "${POD_HOSTNAME}" \
    --port2 "${POD_LDAPS_PORT}" \
    --useSSL2 \
    --replicationPort2 "${_podReplicationPort}" \
    --bindDN2 "${ROOT_USER_DN}" \
    --bindPasswordFile2 "${ROOT_USER_PASSWORD_FILE}" \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --no-prompt --ignoreWarnings \
    "$@" \
    --noSchemaReplication \
    --enableDebug --globalDebugLevel verbose

_replEnableResult=$?
test "${VERBOSE}" != "true" && set +x
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

#
#- * Initialize replication
#

# Rebuild positional arguments with just the --baseDN arguments (remove the --restricted arguments)
set -- --baseDN "${USER_BASE_DN}"
_baseDNs="${REPLICATION_BASE_DNS}"
_iter=""
if test -n "${_baseDNs}"; then
    while test "${_baseDNs}" != "${_iter}"; do
        # Extract the base DN from start of string up to ';' delimiter.
        _iter=${_baseDNs%%;*}
        # Delete the first base DN and the ';' from REPLICATION_BASE_DNS
        _baseDNs="${_baseDNs#"${_iter}";}"
        # Add the --baseDN argument for the extracted base DN
        set -- "$@" --baseDN "${_iter}"
    done
fi

# First, initialize using the topology json file as normal
echo "Initializing replication on POD Server"
set -x
dsreplication initialize \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --topologyFilePath "${TOPOLOGY_FILE}" \
    --hostDestination "${POD_HOSTNAME}" --portDestination "${POD_LDAPS_PORT}" --useSSLDestination \
    "$@" \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
    --no-prompt \
    --enableDebug \
    --globalDebugLevel verbose
_replInitResult=$?
test "${VERBOSE}" != "true" && set +x

if test ${_replInitResult} -eq 0 && test -n "${RESTRICTED_BASE_DNS}" && test -n "${INITIALIZE_SOURCE_HOSTNAME}"; then
    # If using entry balancing, initialize from a specific server in the same replication set, rather
    # than from a topology file. This ensures that any restricted DNs get initialized properly.
    # The INITIALIZE_SOURCE_HOSTNAME and INITIALIZE_SOURCE_LDAPS_PORT values should be set in the
    # prepareToJoinTopology function.

    # Rebuild positional args with only the restricted DNs
    set --
    _iter=""
    _restrictedDNs="${RESTRICTED_BASE_DNS}"
    if test -n "${_restrictedDNs}"; then
        while test "${_restrictedDNs}" != "${_iter}"; do
            # Extract the DN from start of string up to ';' delimiter.
            _iter=${_restrictedDNs%%;*}
            # Delete the first DN and the ';' from _restrictedDNs
            _restrictedDNs="${_restrictedDNs#"${_iter}";}"
            # Add the --baseDN argument for the extracted DN
            set -- "$@" --baseDN "${_iter}"
        done
    fi

    echo "Initializing replication for specific entry balancing replication set on POD Server"
    set -x
    dsreplication initialize \
        --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
        --trustAll \
        --hostSource "${INITIALIZE_SOURCE_HOSTNAME}" \
        --portSource "${INITIALIZE_SOURCE_LDAPS_PORT}" \
        --hostDestination "${POD_HOSTNAME}" \
        --portDestination "${POD_LDAPS_PORT}" \
        --useSSLSource \
        --useSSLDestination \
        "$@" \
        --adminUID "${ADMIN_USER_NAME}" \
        --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
        --no-prompt \
        --enableDebug \
        --globalDebugLevel verbose
    _replInitResult=$?
    test "${VERBOSE}" != "true" && set +x
fi

echo "Replication initialize result=${_replInitResult}"

test ${_replInitResult} -eq 0 && set_server_available online && dsreplication status --displayServerTable --showAll

exit ${_replInitResult}
