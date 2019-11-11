#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook runs after the PingDirectory service has been started and is running.  It
#- will determine if it is part of a directory replication topology by the presence
#- of a TOPOLOGY_SERVICE_BAME .  If not present, then replication will not be enabled.  
#- Otherwise,
#- it will perform the following steps regarding replication.
#-
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"
# shellcheck source=pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

#
# If we are in GENESIS State, then, no replication will be setup
#
if test "${PD_STATE}" == "GENESIS" ; then
    echo "PD_STATE is GENESIS ==> Replication on this server won't be setup until more instances are added"
    exit 0
fi

# If a topology.json file is provided externally, then just use that.
if test -f "${TOPOLOGY_FILE}"; then
    echo "${TOPOLOGY_FILE} exists, not generating it"
else
    # Generate the topology json file
    sh "${HOOKS_DIR}/81-generate-topology-json.sh"
    test $? -ne 0 && exit 0
fi

_myHostname=$( hostname -f )

#- - Wait for DNS lookups to work, sleeping until successful
echo "Waiting until DNS lookup works for ${HOSTNAME}. Running nslookup test..."
while true; do
  nslookup "${HOSTNAME}" 2>/dev/null >/dev/null && echo "  dns is up" && break
  sleep_at_most 5
done

# _myIP=$( getIP "${HOSTNAME}"  )
# _firstHostname=$( getFirstHostInTopology )
# _firstIP=$( getIP "${_firstHostname}" )

#- - If my instance is the first one to come up, then replication enablement will be skipped.
# if test "${_myIP}" = "${_firstIP}" ; then
#   echo "Skipping replication on first container"
#   exit 0
# fi

#- - Wait until a successful ldapsearch an be run on (this may take awhile when a bunch of instances are started simultaneiously):
#-   - my instance
#-   - first instance in the TOPOLOGY_FILE
echo
echo "Running ldapsearch test on this container (${HOSTNAME})"
waitUntilLdapUp "localhost" "${LDAPS_PORT}" ""

# this container is going to need to initialize over the network
# if all containers start at the same time then the first container
# will import the data which takes some time
#echo "Running ldapsearch test on first container (${_firstHostname})"
#waitUntilLdapUp "${_firstHostname}" "${LDAPS_PORT}" "${USER_BASE_DN}"

#- - Change the customer name to my instance hostname
# shellcheck disable=SC2039
echo "Changing the cluster name to ${HOSTNAME}"
# shellcheck disable=SC2039,SC2086
dsconfig --no-prompt \
  --useSSL --trustAll \
  --hostname "${HOSTNAME}" --port "${LDAPS_PORT}" \
  set-server-instance-prop \
  --instance-name "${HOSTNAME}" \
  --set cluster-name:"${HOSTNAME}" >/dev/null 2>/dev/null

#- - Check to see if my hostname is already in the replication topology.  If it is, then exit
# shellcheck disable=SC2039
#echo "Checking if ${HOSTNAME} is already in replication topology"
# shellcheck disable=SC2039,SC2086
#if dsreplication --no-prompt status \
#  --useSSL \
#  --trustAll \
#  --script-friendly \
#  --port ${LDAPS_PORT} \
#  --adminUID "${ADMIN_USER_NAME}" \
#  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
#  | awk '$1 ~ /^Server:$/ {print $2}' \
#  | grep "${HOSTNAME}"; then
#  echo "${HOSTNAME} is already in replication topology"
#  exit 0
#fi

#- - To ensure a clean toplogy, call 81-repair-toplogy.sh to mend the TOPOLOGY_FILE before replciation steps taken
# the topology might need to be mended before new containers can join
#sh "${HOOKS_DIR}/81-repair-topology.sh"

#- - Enable replication
echo "Running dsreplication enable"
# shellcheck disable=SC2039,SC2086
if test "${DISABLE_SCHEMA_REPLICATION}" = 'true'; then
    NO_SCHEMA_REPL_OPTION="--noSchemaReplication"
fi

dsreplication enable \
  --topologyFilePath "${TOPOLOGY_FILE}" \
  --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
  --bindDN1 "${ROOT_USER_DN}" --bindPasswordFile1 "${ROOT_USER_PASSWORD_FILE}" \
  --host2 "${HOSTNAME}" --port2 "${LDAPS_PORT}" --useSSL2 --trustAll \
  --bindDN2 "${ROOT_USER_DN}" --bindPasswordFile2 "${ROOT_USER_PASSWORD_FILE}" \
  --replicationPort2 "${REPLICATION_PORT}" \
  --adminUID "${ADMIN_USER_NAME}" --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --no-prompt \
  --ignoreWarnings \
  --baseDN "${USER_BASE_DN}" ${NO_SCHEMA_REPL_OPTION} \
  --enableDebug \
  --globalDebugLevel verbose
_replEnableResult=$?

if test ${_replEnableResult} -ne 0 && test ${_replEnableResult} -ne 5; then
    echo "Replication already enabled for ${HOSTNAME} (result=${_replEnableResult})"
    exit ${_replEnableResult}
fi

#- - Initialize replication
echo "Running dsreplication initialize"
# shellcheck disable=SC2039,SC2086
dsreplication initialize \
  --topologyFilePath "${TOPOLOGY_FILE}" \
  --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
  --useSSLDestination \
  --trustAll \
  --hostDestination "${HOSTNAME}" \
  --portDestination ${LDAPS_PORT} \
  --baseDN "${USER_BASE_DN}" \
  --adminUID "${ADMIN_USER_NAME}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --no-prompt \
  --enableDebug \
  --globalDebugLevel verbose

_replInitResult=$?

if test ! ${_replInitResult} -eq 0 ; then
    echo "Unable to initialized replication (result=${_replInitResult})"
    exit ${_replInitResult}
else 
    echo "Successful initialization."
    dsreplication status --displayServerTable --showAll
fi
