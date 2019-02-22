#!/bin/sh
set -ex

TOP_FILE="${IN_DIR}/topology.json"

if test ! -f "${TOP_FILE}" ; then
  echo "${TOP_FILE} not found"
  exit 0
fi

FQDN=$(hostname -f)
echo "Waiting until DNS lookup works for ${FQDN}" 
while true; do
  echo "Running nslookup test"
  nslookup "$FQDN" && break

  echo "Sleeping for a few seconds"
  sleep 5
done

while true; do
  echo "Running ldapsearch test"
  ldapsearch -T --terse -p ${LDAPS_PORT} -Z -X -b "" -s base "(&)" 1.1 && break

  echo "Sleeping for a few seconds"
  sleep $(( $RANDOM % 15 ))
done

echo "Changing the cluster name to ${HOSTNAME}"
dsconfig --no-prompt \
  --useSSL --trustAll \
  --hostname "${HOSTNAME}" --port ${LDAPS_PORT} \
  set-server-instance-prop \
  --instance-name "${HOSTNAME}" \
  --set cluster-name:"${HOSTNAME}"

echo "Checking if ${HOSTNAME} is already in replication topology"
if dsreplication --no-prompt status \
  --useSSL --trustAll \
  --port ${LDAPS_PORT} \
  --adminUID "${ADMIN_USER_NAME}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  | grep "${HOSTNAME}"; then
  echo "${HOSTNAME} is already in replication topology"
  exit 0
fi

echo "Running dsreplication enable"
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
  --no-prompt --ignoreWarnings \
  --baseDN "${USER_BASE_DN}" \
  --enableDebug --globalDebugLevel verbose

echo "Running dsreplication initialize"
dsreplication initialize \
  --topologyFilePath "${TOP_FILE}" \
  --useSSLDestination --trustAll \
  --hostDestination "${HOSTNAME}" \
  --portDestination ${LDAPS_PORT} \
  --baseDN "${USER_BASE_DN}" \
  --adminUID "${ADMIN_USER_NAME}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --no-prompt \
  --enableDebug --globalDebugLevel verbose
