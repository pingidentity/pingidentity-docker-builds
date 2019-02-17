#!/bin/sh
set -ex

LOG_FILE="${OUT_DIR}/entrypoint.log"

echo "Starting entrypoint script" | tee -a $LOG_FILE

if [[ "$1" = 'start-server' ]]; then
  # lay down the bits from the immutable volume to the runtime volume
  test -d "${SERVER_ROOT_DIR}" || cp -rf /opt/server ${SERVER_ROOT_DIR}

  # Only do the init stuff if this is the first time the container is starting
  if [[ ! -f "${SERVER_ROOT_DIR}/config/server.uuid" ]]; then
    echo "Initializing server for the first time" | tee -a $LOG_FILE

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
    test -d ${IN_DIR}/instance && cp -rf ${IN_DIR}/instance ${OUT_DIR}

    test -f "${LICENSE_KEY_FILE}" && cp -f "${LICENSE_KEY_FILE}" "${SERVER_ROOT_DIR}/${KEY_FILE_NAME}"

    test -f "${SERVER_ROOT_DIR}/${KEY_FILE_NAME}" || (echo "License File absent" && exit 89)

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
      --baseDN "${USER_BASE_DN}" \
      --addBaseEntry --doNotStart 2>&1 | tee -a ${LOG_FILE}

    echo "Configuring tools.properties file" | tee -a ${LOG_FILE}
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
    --offline | tee -a ${LOG_FILE}

    test -f ${IN_DIR}/ds-config-changes.dsconfig && dsconfig -n --offline --suppressMirroredDataChecks -F ${IN_DIR}/ds-config-changes.dsconfig

    # # Run shell scripts
    # for f in "${IN_DIR}"/*.sh; do
    #   echo "Running shell script: $f" >> $LOG_FILE
    #   /bin/sh -x $f
    # done

    test -f ${IN_DIR}/users.ldif && import-ldif -n userRoot --ldifFile ${IN_DIR}/users.ldif
    # Now import LDIF files, if any are present
    # args=
    # for f in "${IN_DIR}"/*.ldif; do
    #   args="$args --ldifFile $f"
    # done
    # if [ ! -z "$args" ]; then
    #   echo "Importing LDIF file: $args" >> $LOG_FILE
    #   import-ldif --backendID userRoot $args
    # fi  

  fi

  # Kick off the post start script in the background. This will set up
  # replication when the server is started.
  echo "Running postStart in the background" | tee -a $LOG_FILE
  /opt/postStart.sh &

  echo "Copying $LOG_FILE to ${SERVER_ROOT_DIR}/logs"| tee -a>> $LOG_FILE
  cp "${LOG_FILE}" "${SERVER_ROOT_DIR}/logs"

  tail -F "${SERVER_ROOT_DIR}/logs/access" &
  exec start-server "--nodetach" 
fi

exec "$@"
