#!/usr/bin/env sh
set -x

if test ! -f "${TOPOLOGY_FILE}" ; then
  echo "${TOPOLOGY_FILE} not found"
  exit 0
fi

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"
# shellcheck source=../pingcommon/lib.sh
test -f "${BASE}/lib.sh" && . "${BASE}/lib.sh"
# shellcheck source=pingdirectory.lib.sh
test -f "${BASE}/pingdirectory.lib.sh" && . "${BASE}/pingdirectory.lib.sh"


# jq -r '.|.serverInstances[]|select(.product=="DIRECTORY")|.hostname' < /opt/staging/topology.json
FIRST_HOSTNAME=$( getFirstHostInTopology )
FQDN=$( hostname -f )

echo "Waiting until DNS lookup works for ${FQDN}" 
while true; do
  echo "Running nslookup test"
  nslookup "${FQDN}" && break

  echo "Sleeping for a few seconds"
  sleep_at_most 5
done

MYIP=$( getIP ${FQDN}  )
FIRST_IP=$( getIP "${FIRST_HOSTNAME}" )

if test "${MYIP}" = "${FIRST_IP}" ; then
  echo "******************"
  echo "Skipping replication on first container"
  echo "******************"
  exit 99
fi

while true; do
  echo "Running ldapsearch test on this container"
  # shellcheck disable=SC2086
  ldapsearch -T --terse --suppressPropertiesFileComment -p ${LDAPS_PORT} -Z -X -b "" -s base "(&)" 1.1 2>/dev/null && break

  echo "Sleeping for a few seconds"
  sleep_at_most 15
done

# this container is going to need to initialize over the network
# if all containers start at the same time then the fisrt container
# will import the data which takes some time
while true; do
  echo "Running ldapsearch test on first container"
  # shellcheck disable=SC2086
  ldapsearch -T --terse --suppressPropertiesFileComment -h ${FIRST_HOSTNAME} -p ${LDAPS_PORT} -Z -X -b "${USER_BASE_DN}" -s base "(&)" 1.1 2>/dev/null && break

  echo "Sleeping for a few seconds"
  sleep_at_most 15
done

# shellcheck disable=SC2039
echo "Changing the cluster name to ${HOSTNAME}"
# shellcheck disable=SC2039,SC2086
dsconfig --no-prompt \
  --useSSL --trustAll \
  --hostname "${HOSTNAME}" --port ${LDAPS_PORT} \
  set-server-instance-prop \
  --instance-name "${HOSTNAME}" \
  --set cluster-name:"${HOSTNAME}"

# shellcheck disable=SC2039
echo "Checking if ${HOSTNAME} is already in replication topology"
# shellcheck disable=SC2039,SC2086
if dsreplication --no-prompt status \
  --useSSL \
  --trustAll \
  --script-friendly \
  --port ${LDAPS_PORT} \
  --adminUID "${ADMIN_USER_NAME}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  | awk '$1 ~ /^Server:$/ {print $2}' \
  | grep "${HOSTNAME}"; then
  echo "${HOSTNAME} is already in replication topology"
  exit 0
fi

####
# cleanup the replication topology in case it has some defunct servers
###
status=$( dsreplication status --script-friendly )
firstLiveServer=$( echo "${status}" | awk 'BEGIN {s=""} $1~/Server:/{s=$2} $1~/Entries:/ && $2!~/N\/A/{print s;exit 0}' )
# shellcheck disable=2086,2039
dsconfig \
    --no-prompt \
    --useSSL \
    --trustAll \
    --hostname "${firstLiveServer}" \
    --port ${LDAPS_PORT} \
    set-global-configuration-prop \
    --set force-as-master-for-mirrored-data:true    
for defunctServer in $( echo "${status}" | awk '$0 ~ /^Error on/ {split($3,a,":");print a[1]}' ) ; do
    remove-defunct-server \
        --serverInstanceName "${defunctServer}" \
        --bindDN "${ROOT_USER_DN}" \
        --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
        --enableDebug \
        --globalDebugLevel verbose \
        --no-prompt
done

echo "Running dsreplication enable"
# shellcheck disable=SC2039,SC2086
dsreplication enable \
  --topologyFilePath "${TOPOLOGY_FILE}" \
  --bindDN1 "${ROOT_USER_DN}" \
  --bindPasswordFile1 "${ROOT_USER_PASSWORD_FILE}" \
  --useSSL2 --trustAll \
  --host2 "${HOSTNAME}" --port2 ${LDAPS_PORT} \
  --bindDN2 "${ROOT_USER_DN}" \
  --bindPasswordFile2 "${ROOT_USER_PASSWORD_FILE}" \
  --replicationPort2 ${REPLICATION_PORT} \
  --adminUID "${ADMIN_USER_NAME}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --no-prompt \
  --ignoreWarnings \
  --baseDN "${USER_BASE_DN}" \
  --enableDebug \
  --globalDebugLevel verbose

echo "Running dsreplication initialize"
# shellcheck disable=SC2039,SC2086
dsreplication initialize \
  --topologyFilePath "${TOPOLOGY_FILE}" \
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
