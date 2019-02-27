#!/usr/bin/env sh
set -x

LOG_FILE="${SERVER_ROOT_DIR}/logs/preStop.log"
TOPOLOGY_FILE="${IN_DIR}/topology.json"

if ! test  -f "${TOPOLOGY_FILE}" ; then
  echo "${TOPOLOGY_FILE} not found" > "${LOG_FILE}"
  exit 0
fi

{
  # shellcheck disable=SC2039
  echo "Starting preStop script on ${HOSTNAME}"
  echo "Disabling LDAP connection handler"
} > "${LOG_FILE}"

# shellcheck disable=SC2039,SC2086
dsconfig --no-prompt \
  --useSSL --trustAll \
  --hostname "${HOSTNAME}" --port ${LDAPS_PORT} \
  set-connection-handler-prop \
  --handler-name "LDAP Connection Handler" \
  --set enabled:false >> "${LOG_FILE}" 2>&1

echo "Forcing one of the servers as master" >> "${LOG_FILE}"
forcedMaster=

for h in $(grep hostname "${TOPOLOGY_FILE}" | cut -d':' -f 2 | tr -d '", '); do
  echo "Trying search on ${h}:${LDAPS_PORT}" >> "${LOG_FILE}"

  # shellcheck disable=SC2086
  if ldapsearch -T --terse --suppressPropertiesFileComment -h "${h}" -p ${LDAPS_PORT} -Z -X -b "" -s base "(&)" 2>/dev/null ; then
    echo "Forcing server ${h} as master" >> "${LOG_FILE}"

    if dsconfig --no-prompt \
      --useSSL --trustAll \
      --hostname "${h}" --port ${LDAPS_PORT} \
      set-global-configuration-prop \
      --set force-as-master-for-mirrored-data:true >> "${LOG_FILE}" 2>&1; then

      forcedMaster="${h}"
      echo "Forced ${h} as master" >> "${LOG_FILE}"

      break
    fi
  fi
done

# Sleep for a couple of seconds for a master to be forced, if required
sleep 2

test -f "${ROOT_USER_PASSWORD_FILE}"  \
  && ROOT_PASSWORD_ARGS="--bindPasswordFile ${ROOT_USER_PASSWORD_FILE}" \
  || ROOT_PASSWORD_ARGS="--bindPassword ${ROOT_USER_PASSWORD}"

echo "Removing local defunct server using ${TOPOLOGY_FILE}" >> "${LOG_FILE}"
# shellcheck disable=SC2039,SC2086
remove-defunct-server --serverInstanceName ${HOSTNAME} \
  --topologyFilePath "${TOPOLOGY_FILE}" \
  --bindDN "${ROOT_USER_DN}" \
  ${ROOT_PASSWORD_ARGS} \
  --enableDebug --globalDebugLevel verbose \
  --no-prompt >> "${LOG_FILE}" 2>&1

if grep "No existing server selected for removal" "${LOG_FILE}"; then
  echo "Removing local defunct server using config.ldif file" >> "${LOG_FILE}"
  # shellcheck disable=SC2039,SC2086
  remove-defunct-server --serverInstanceName "${HOSTNAME}" \
    --bindDN "${ROOT_USER_DN}" \
    ${ROOT_PASSWORD_ARGS} \
    --enableDebug --globalDebugLevel verbose \
    --no-prompt >> "${LOG_FILE}" 2>&1  
fi

if test -f "${SERVER_ROOT_DIR}"/config/config.ldif.init ; then
  echo "Restoring init config" >> "${LOG_FILE}"
  cp "${SERVER_ROOT_DIR}"/config/config.ldif "${SERVER_ROOT_DIR}"/config/config.ldif.init
fi

if ! test -z "${forcedMaster}" ; then
  echo "Unforcing server ${forcedMaster} as master" >> "${LOG_FILE}"
  # shellcheck disable=SC2086
  dsconfig --no-prompt \
    --useSSL --trustAll \
    --hostname "${forcedMaster}" --port ${LDAPS_PORT} \
    set-global-configuration-prop \
    --set force-as-master-for-mirrored-data:false >> "${LOG_FILE}" 2>&1
fi
