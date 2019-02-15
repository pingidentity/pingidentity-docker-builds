#!/bin/sh
set -ex

LOG_FILE="${SERVER_ROOT_DIR}/logs/postStart.log"
TOP_FILE="${IN_DIR}/topology.json"

echo "Starting postStart script on ${HOSTNAME}" > $LOG_FILE

if [[ ! -f "${TOP_FILE}" ]]; then
  echo "${TOP_FILE} not found" >> $LOG_FILE
  exit 0
fi

FQDN=$(hostname -f)
echo "Waiting until DNS lookup works for ${FQDN}" >> $LOG_FILE
while true; do
  echo "Running nslookup test" >> $LOG_FILE
  nslookup "$FQDN" && break

  echo "Sleeping for a few seconds" >> $LOG_FILE
  sleep 5
done

echo "Waiting until the server is up and running" >> $LOG_FILE
while true; do
  echo "Running ldapsearch test" >> $LOG_FILE
  ldapsearch -p ${LDAPS_PORT} -Z -X -b "" -s base "(&)" && break

  echo "Sleeping for a few seconds" >> $LOG_FILE
  sleep 5
done

echo "Changing the cluster name to ${HOSTNAME}" >> $LOG_FILE
dsconfig --no-prompt \
  --useSSL --trustAll \
  --hostname "${HOSTNAME}" --port ${LDAPS_PORT} \
  set-server-instance-prop \
  --instance-name "${HOSTNAME}" \
  --set cluster-name:"${HOSTNAME}" >> $LOG_FILE 2>&1

echo "Checking if ${HOSTNAME} is already in replication topology" >> $LOG_FILE
if dsreplication --no-prompt status \
  --useSSL --trustAll \
  --port ${LDAPS_PORT} \
  --adminUID "${ADMIN_USER_NAME}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  grep "${HOSTNAME}"; then
  echo "${HOSTNAME} is already in replication topology" >> $LOG_FILE
  exit 0
fi

echo "Running dsreplication enable" >> $LOG_FILE
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
  --enableDebug --globalDebugLevel verbose >> $LOG_FILE 2>&1

echo "Running dsreplication initialize" >> $LOG_FILE
dsreplication initialize \
  --topologyFilePath "${TOP_FILE}" \
  --useSSLDestination --trustAll \
  --hostDestination "${HOSTNAME}" \
  --portDestination ${LDAPS_PORT} \
  --baseDN "${USER_BASE_DN}" \
  --adminUID "${ADMIN_USER_NAME}" \
  --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
  --no-prompt \
  --enableDebug --globalDebugLevel verbose >> $LOG_FILE 2>&1
