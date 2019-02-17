#!/bin/sh
set -ex

if test "${1}" = "start-server" ; then
  # Only do the init stuff if this is the first time the container is starting
  if ! test -f "${SERVER_ROOT_DIR}/config/server.uuid" ; then
    # lay down the bits
    test -d "${SERVER_ROOT_DIR}" || cp -af /opt/server ${SERVER_ROOT_DIR}

    if ! test -z "${SERVER_PROFILE_URL}" ; then
      # deploy configuration if provided
      git clone ${SERVER_PROFILE_URL} /opt/server-profile | tee -a ${LOG_FILE}
      if ! test -z "${SERVER_PROFILE_BRANCH}" ; then
        cd /opt/server-profile
        git checkout ${SERVER_PROFILE_BRANCH}
        cd -
      fi
      cp -af /opt/server-profile/* /opt/in
    fi

    test -f /opt/in/env_vars && source /opt/in/env_vars

    # Copy the provided file in the input volume
    test -d ${IN_DIR}/instance && cp -af ${IN_DIR}/instance ${OUT_DIR}

    test -f "${LICENSE_KEY_FILE}" && cp "${LICENSE_KEY_FILE}" "${SERVER_ROOT_DIR}/${KEY_FILE_NAME}"

    "${SERVER_ROOT_DIR}"/setup \
      --no-prompt \
      --verbose \
      --acceptLicense \
      --instanceName "${HOSTNAME}" \
      --location "${LOCATION}" \
      --maxHeapSize "${MAX_HEAP_SIZE}" \
      --ldapPort ${LDAP_PORT} \
      --enableStartTLS \
      --ldapsPort ${LDAPS_PORT} \
      --httpsPort ${HTTPS_PORT} \
      --generateSelfSignedCertificate \
      --rootUserDN "${ROOT_USER_DN}" \
      --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
      --doNotStart 2>&1

    /opt/configure-tools.sh \
        ${LDAP_PORT} \
        "${ROOT_USER_DN}" \
        "${ROOT_USER_PASSWORD_FILE}" \
        "${ADMIN_USER_NAME}" \
        "${ADMIN_USER_PASSWORD_FILE}"

    dsconfig set-connection-handler-prop \
    --handler-name "HTTPS Connection Handler"  \
    --reset web-application-extension \
    --no-prompt \
    --suppressMirroredDataChecks \
    --offline
    
    test -f ${IN_DIR}/ds-config-changes.dsconfig && \
      dsconfig -n --offline --suppressMirroredDataChecks -F ${IN_DIR}/ds-config-changes.dsconfig
  fi

  # Kick off the post start script in the background. This will set up
  # replication when the server is started.
  echo "Running postStart in the background"
  /opt/postStart.sh &

  tail -F "${SERVER_ROOT_DIR}/logs/sync" &
  exec start-server "--nodetach"
else
  exec "$@"
fi