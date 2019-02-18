#!/bin/env sh
set -x

# a function to base the execution of a script upon the presence or absence of a file
function run_if ()
{
	mode=$1
	shift

	runFile=$1


	if test -z "$2" ; then
    if test "${mode}" = "absent" ; then
      echo "error, when mode=absent a test file must be provide as a third argument"
      exit 9
    fi
		testFile=$1
	else
		testFile=$2
	fi

	if test $mode = "present" ; then
		if test -f "${testFile}" ; then
			sh ${runFile}
		fi
	else
		if ! test -f "${testFile}" ; then
			sh ${runFile}
		fi		
	fi
}

function apply_tools_properties ()
{
    /opt/configure-tools.sh \
        ${LDAP_PORT} \
        "${ROOT_USER_DN}" \
        "${ROOT_USER_PASSWORD_FILE}" \
        "${ADMIN_USER_NAME}" \
        "${ADMIN_USER_PASSWORD_FILE}"
}

function apply_configuration ()
{
  if test -d ${IN_DIR}/config && ! test -z "$( ls -A ${IN_DIR}/config/*.dsconfig 2>/dev/null )" ; then
    for batch in $( ls -A1 ${IN_DIR}/config/*.dsconfig 2>/dev/null | sort | uniq ) ; do
        cat ${batch} >> ${SERVER_ROOT_DIR}/tmp/config.batch
        # this guards against provided config batches that don't end with a blank line
        echo >> ${SERVER_ROOT_DIR}/tmp/config.batch
    done
  fi 

  cat >>${SERVER_ROOT_DIR}/tmp/config.batch <<END

  dsconfig set-connection-handler-prop \
    --handler-name "HTTPS Connection Handler"  \
    --reset web-application-extension

END

  ${SERVER_ROOT_DIR}/bin/dsconfig \
    --no-prompt \
    --suppressMirroredDataChecks \
    --offline \
    --batch-file ${SERVER_ROOT_DIR}/tmp/config.batch
}

function apply_server_profile ()
{
  if ! test -z "${SERVER_PROFILE_URL}" ; then
    # deploy configuration if provided
    git clone ${SERVER_PROFILE_URL} /opt/server-profile | tee -a ${LOG_FILE}
    if ! test -z "${SERVER_PROFILE_BRANCH}" ; then
      cd /opt/server-profile
      git checkout ${SERVER_PROFILE_BRANCH}
    fi
    cp -af /opt/server-profile/* /opt/in
  fi
  test -d ${IN_DIR}/instance && cp -af ${IN_DIR}/instance ${OUT_DIR}
}

function apply_extensions ()
{
  if test -d ${IN_DIR}/extensions && ! test -z "$( ls -A ${IN_DIR}/extensions/*.zip 2>/dev/null )" ; then
    for extension in $( ls -1 ${IN_DIR}/extensions/*.zip ) ; do 
        ${SERVER_ROOT_DIR}/bin/manage-extension --install ${extension} --no-prompt
    done
  fi
}


function deploy_server_bits ()
{
  test -d "${SERVER_ROOT_DIR}" || cp -af /opt/server ${SERVER_ROOT_DIR}
}

function apply_license_file ()
{
  test -f "${LICENSE_KEY_FILE}" && cp -f "${LICENSE_KEY_FILE}" "${SERVER_ROOT_DIR}/${KEY_FILE_NAME}"
}

function apply_debug_configuration ()
{
  if test "${PING_DEBUG}" = "true" ; then
    mv ${SERVER_ROOT_DIR}/config/java.properties ${SERVER_ROOT_DIR}/config/java.properties.orig
    awk '/^start-server.java/ {print;print "  -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005 \\";next;}1' ${SERVER_ROOT_DIR}/config/java.properties.orig > ${SERVER_ROOT_DIR}/config/java.properties
    ${SERVER_ROOT_DIR}/bin/dsjavaproperties
  fi
}

function check_for_license ()
{
  test -f "${SERVER_ROOT_DIR}/${KEY_FILE_NAME}" || (echo "License File absent" && exit 89)
}

function setup_server_instance ()
{
  certificateOptions="      --generateSelfSignedCertificate"
  if test -f ${SERVER_ROOT_DIR}/config/keystore && test -f ${SERVER_ROOT_DIR}/config/keystore.pin ; then
    certificateOptions="      --useJavaKeystore ${SERVER_ROOT_DIR}/config/keystore --keyStorePasswordFile ${SERVER_ROOT_DIR}/config/keystore.pin"
  elif test -f ${SERVER_ROOT_DIR}/config/keystore.p12 && test -f ${SERVER_ROOT_DIR}/config/keystore.pin ; then
    certificateOptions="      --usePkcs12Keystore ${SERVER_ROOT_DIR}/config/keystore --keyStorePasswordFile ${SERVER_ROOT_DIR}/config/keystore.pin"
  fi

  if test -f ${SERVER_ROOT_DIR}/config/truststore ; then
    certificateOptions="      --useJavaTruststore ${SERVER_ROOT_DIR}/config/keystore"
  elif test -f ${SERVER_ROOT_DIR}/config/truststore.p12 ; then
    certificateOptions="      --usePkcs12Truststore ${SERVER_ROOT_DIR}/config/keystore"
  fi
  if test -f ${SERVER_ROOT_DIR}/config/truststore.pin ; then
    certificateOptions="${certificateOptions} --trustStorePasswordFile ${SERVER_ROOT_DIR}/config/truststore.pin"
  fi
  certificateOptions="${certificateOptions} --certNickname ${CERTIFICATE_NICKNAME}"

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
}

function first_time_sequence ()
{
  # Only do the init stuff if this is the first time the container is starting
  if test ! -f "${SERVER_ROOT_DIR}/config/server.uuid" ; then
    echo "Initializing server for the first time" | tee -a $LOG_FILE
    run_if present ${IN_DIR}/hooks/10-before-copying-bits.sh
    # lay down the bits from the immutable volume to the runtime volume
    deploy_server_bits

    # apply the server profile provided
    apply_server_profile

    # environment variables will be provided by the server profile
    test -f ${IN_DIR}/env_vars && source ${IN_DIR}/env_vars    

    # apply the license file provided
    apply_license_file

    # check the license file is present
    check_for_license

    run_if present ${IN_DIR}/hooks/20-before-setup.sh

    # setup the instance given all the provided data
    setup_server_instance

    # apply the tools properties for convenience
    apply_tools_properties

    # install custom extension provided
    apply_extensions

    run_if present ${IN_DIR}/hooks/30-before-configuration.sh
    # apply custom configuration provided
    apply_configuration
  fi
}

if test "$1" = 'start-server' ; then
  run_if present ${IN_DIR}/hooks/00-immediate-startup.sh

  first_time_sequence

  run_if present ${IN_DIR}/hooks/50-before-post-start.sh

  apply_debug_configuration

  # Kick off the post start script in the background.
  # this may be used to initialize sync sources and start pipes
  run_if present ${IN_DIR}/hooks/80-post-start.sh &

  tail -F "${SERVER_ROOT_DIR}/logs/access" &
  exec start-server "--nodetach" 
else
  exec "$@"
fi
