#!/bin/bash
set -ex

LOG_FILE="/tmp/entrypoint.log"
# err_report() {
#   echo "Error on line $1" >> $LOG_FILE
#   cp "${LOG_FILE}" "${SERVER_ROOT_DIR}/logs"
# }
# trap 'err_report $LINENO' ERR

echo "Starting entrypoint script" | tee -a $LOG_FILE

if [ "$1" = 'start-server' ]; then
  # Only do the init stuff if this is the first time the container is starting
  if [[ ! -f "${SERVER_ROOT_DIR}/config/server.uuid" ]]; then
    echo "Initializing server for the first time" | tee -a $LOG_FILE 
    unzip -o "${SERVER_ZIP_FILE}" -d "${OUT_DIR}"

    cp "${LICENSE_KEY_FILE}" "${SERVER_ROOT_DIR}"
    "${SERVER_ROOT_DIR}"/setup --no-prompt --acceptLicense \
      --instanceName "${HOSTNAME}" \
      --location "${LOCATION}" \
      --maxHeapSize "${MAX_HEAP_SIZE}" \
      --ldapPort ${LDAP_PORT} --enableStartTLS \
      --ldapsPort ${LDAPS_PORT} \
      --httpsPort ${HTTPS_PORT} \
      --generateSelfSignedCertificate \
      --rootUserDN "${ROOT_USER_DN}" \
      --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
      --doNotStart 2>&1 | tee -a $LOG_FILE

    echo "Configuring tools.properties file" | tee -a $LOG_FILE
    /configure-tools.sh \
        ${LDAP_PORT} \
        "${ROOT_USER_DN}" \
        "${ROOT_USER_PASSWORD_FILE}"

    shopt -s nullglob dotglob

    # Copy any schema files first
    for f in "${IN_DIR}"/*-schema.ldif; do
      echo "Copying schema file: $f" >> $LOG_FILE
      cp $f "${SERVER_ROOT_DIR}/config/schema"
    done

    # Now apply any dsconfig files with a 'proxy' prefix
    for f in "${IN_DIR}"/proxy*.dsconfig; do
      echo "Applying dsconfig file: $f" | tee -a $LOG_FILE
      dsconfig --offline --no-prompt --quiet \
        --suppressMirroredDataChecks \
        --batch-file $f
    done

    # Run shell scripts
    for f in "${IN_DIR}"/*.sh; do
      echo "Running shell script: $f" | tee -a $LOG_FILE
      /bin/bash $f
    done

    # wait for external servers to be ready to prepare them
    END=${NUM_DS_REPLICAS}
    
    for ((i=0;i<END;i++)); do
      [[ -z "${K8S_SERVICE_NAME}" || -z "${K8S_STATEFUL_SET_NAME}" ]] && \
        FQDN=ds-$i.ds-topology || \
        FQDN="${K8S_STATEFUL_SET_NAME}-$i.${K8S_SERVICE_NAME}"

      echo "Waiting until server ${FQDN} is ready"
    
      while true; do
        echo "Running ldapsearch test"
        ldapsearch -h "${FQDN}" \
            -p ${LDAPS_PORT} -Z -X -b "" -s base "(&)" && break

        echo "Sleeping for a few seconds"
        sleep 5
      done
    done

    # set up the external ldap servers
    echo "Setting up external ldap servers for proxy" | tee -a $LOG_FILE
    /externalserversetup.sh ${NUM_DS_REPLICAS}

    # Save off the config for the standalone server
    echo "Copying config.ldif into config.ldif.init" | tee -a $LOG_FILE 
    cp "${SERVER_ROOT_DIR}"/config/config.ldif{,.init}
  fi

  echo "Copying $LOG_FILE to ${SERVER_ROOT_DIR}/logs"| tee -a $LOG_FILE
  cp "${LOG_FILE}" "${SERVER_ROOT_DIR}/logs"

  exec start-server "--nodetach"
fi
  
exec "$@"
