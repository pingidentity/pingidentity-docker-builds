#!/usr/bin/env sh
set -x

TOP_FILE="${STAGING_DIR}/topology.json"

if test ! -f "${TOP_FILE}" ; then
  echo "${TOP_FILE} not found"
  exit 0
fi

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"


# jq -r '.|.serverInstances[]|select(.product=="DIRECTORY")|.hostname' < /opt/staging/topology.json
FIRST_HOSTNAME=$( jq -r '.|[.serverInstances[]|select(.product=="DIRECTORY")]|.[0]|.hostname' < "${TOP_FILE}" )
FQDN=$( hostname -f )

echo "Waiting until DNS lookup works for ${FQDN}" 
while true; do
  echo "Running nslookup test"
  nslookup "${FQDN}" && break

  echo "Sleeping for a few seconds"
  sleep 5
done

MYIP=$( nslookup "${FQDN}"  2>/dev/null | awk '$0 ~ /^Address 1/ {print $3}'  )
FIRST_IP=$( nslookup "${FIRST_HOSTNAME}"  2>/dev/null | awk '$0 ~ /^Address 1/ {print $3}' )

if test "${MYIP}" = "${FIRST_IP}" ; then
  echo "******************"
  echo "Skipping replication on first container"
  echo "******************"
  exit 99
fi

while true; do
  echo "Running ldapsearch test"
  # shellcheck disable=SC2086
  ldapsearch -T --terse --suppressPropertiesFileComment -p ${LDAPS_PORT} -Z -X -b "" -s base "(&)" 1.1 2>/dev/null && break

  echo "Sleeping for a few seconds"
  # RANDOM tested on Alpine
  # shellcheck disable=SC2039
  sleep $(( RANDOM % 15 ))
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

echo "Running dsreplication enable"
# shellcheck disable=SC2039,SC2086
dsreplication enable \
  --topologyFilePath "${TOP_FILE}" \
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
  --topologyFilePath "${TOP_FILE}" \
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
