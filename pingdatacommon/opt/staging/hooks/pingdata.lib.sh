#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# location of setup-arguments file used for PingData products
_setupArgumentsFile="${PD_PROFILE}/setup-arguments.txt"
_configLDIF="${SERVER_ROOT_DIR}/config/config.ldif"

# TODO - With the new manage-profile in directory, many of the options below, should be
# put into the setup-arguments.txt of the pd.profile.  Since they change from an initial
# setup to a replacement (i.e. truststore info).

getCertificateOptions ()
{
    certificateOptions="--generateSelfSignedCertificate"
    if test -f "${SERVER_ROOT_DIR}/config/keystore" && test -f "${SERVER_ROOT_DIR}/config/keystore.pin" ; then
        certificateOptions="--useJavaKeystore ${SERVER_ROOT_DIR}/config/keystore --keyStorePasswordFile ${SERVER_ROOT_DIR}/config/keystore.pin"
    elif test -f "${SERVER_ROOT_DIR}/config/keystore.p12" && test -f "${SERVER_ROOT_DIR}/config/keystore.pin" ; then
        certificateOptions="--usePkcs12Keystore ${SERVER_ROOT_DIR}/config/keystore.p12 --keyStorePasswordFile ${SERVER_ROOT_DIR}/config/keystore.pin"
    fi

    if test -f "${SERVER_ROOT_DIR}/config/truststore" ; then
        certificateOptions="${certificateOptions} --useJavaTruststore ${SERVER_ROOT_DIR}/config/truststore"
    elif test -f "${SERVER_ROOT_DIR}/config/truststore.p12" ; then
        certificateOptions="${certificateOptions} --usePkcs12Truststore ${SERVER_ROOT_DIR}/config/truststore.p12"
    fi
    if test -f "${SERVER_ROOT_DIR}/config/truststore.pin" ; then
        certificateOptions="${certificateOptions} --trustStorePasswordFile ${SERVER_ROOT_DIR}/config/truststore.pin"
    fi
    certificateOptions="${certificateOptions} --certNickname ${CERTIFICATE_NICKNAME:-server-cert}"
    echo "${certificateOptions}"
}

getEncryptionOption ()
{
    encryptionOption="--encryptDataWithRandomPassphrase"

    if test -f "${ENCRYPTION_PASSWORD_FILE}" ; then
        encryptionOption="--encryptDataWithPassphraseFromFile ${ENCRYPTION_PASSWORD_FILE}"
    fi

    echo "${encryptionOption}"
}

is_gte_81() {
  version=$(echo -e ${IMAGE_VERSION} | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
  major=$(echo -e ${version} | awk -F"." '{ print $1 }')
  minor=$(echo -e ${version} | awk -F"." '{ print $2 }')
  if test ${major} -eq 8 && test ${minor} -ge 1 || test ${major} -gt 8; then
    echo 1
  else
    echo 0
  fi
}

getJvmOptions ()
{
    jvmOptions=""
    origMaxHeapSize=""
    if test $( is_gte_81 ) -eq 1 && test "${PING_PRODUCT}" = "PingDirectory"; then
        # If PingDirectory 8.1.0.0 or greater is run and the MAX_HEAP_SIZE is 384m, then it's
        # assumed to have never been set so it'll update it to the minimum needed
        # for version 8.1.0.0 or greater.
        if test "${MAX_HEAP_SIZE}" = "384m"; then
            origMaxHeapSize="${MAX_HEAP_SIZE}"
            MAX_HEAP_SIZE="768m"
        fi
    fi
    if ! test "${MAX_HEAP_SIZE}" = "AUTO" ; then
        jvmOptions="--maxHeapSize ${MAX_HEAP_SIZE}"
    fi
    case "${JVM_TUNING}" in
        NONE|AGGRESSIVE|SEMI_AGGRESSIVE)
            jvmOptions="${jvmOptions} --jvmTuningParameter ${JVM_TUNING}"
            ;;
        *)
            echo_red "**********"
            echo_red "Unsupported JVM_TUNING value [${JVM_TUNING}]"
            echo_red "Value must be NONE, AGGRESSIVE or SEMI_AGGRESSIVE"
            exit 75
            ;;
    esac
    if test origMaxHeapSize != ""; then
        MAX_HEAP_SIZE=${origMaxHeapSize}
    fi
    echo "${jvmOptions}"
}

# Generates a setup-arguments.txt file passed as first parameter
generateSetupArguments ()
{
    # Create product specfic setup arguments and manage-profile setup arguments
    case "${PING_PRODUCT}" in
        PingDataSync|PingDataGovernance|PingDirectoryProxy)
            _pingDataSetupArguments=""
            _pingDataManageProfileSetupArgs=""
            ;;
        PingDirectory)
            _pingDataSetupArguments="${encryptionOption} \
                                    --baseDN \"${USER_BASE_DN}\" \
                                    --addBaseEntry "
            _doesStartWith8=$( echo "${LICENSE_VERSION}" | sed 's/^8.*//' )
            if test -z "${_doesStartWith8}"
            then
                _pingDataManageProfileSetupArgs="--addMissingRdnAttributes"
            fi
            _pingDataManageProfileSetupArgs="${_pingDataManageProfileSetupArgs:+${_pingDataManageProfileSetupArgs} }--rejectFile /tmp/rejects.ldif ${_skipImports}"
            ;;
        *)
            echo_red "Unknown PING_PRODUCT value [${PING_PRODUCT}]"
            exit 182
            ;;
    esac

    if test "${RUN_PLAN}" = "RESTART" ; then
        _prevSetupArgs="${SERVER_ROOT_DIR}/config/.manage-profile-setup-arguments.txt"
        _prevLdapsPort=$(sed -n 's/.*--ldapsPort \([0-9]*\).*/\1/p' < "${_prevSetupArgs}")
        _prevLdapPort=$(sed -n 's/.*--ldapPort \([0-9]*\).*/\1/p' < "${_prevSetupArgs}")
        _prevHttpsPort=$(sed -n 's/.*--httpsPort \([0-9]*\).*/\1/p' < "${_prevSetupArgs}")

        # Check to see if there is an attempt to change the ports.  If so, emit an error and fail
        if test "${_prevLdapPort}" != "${LDAP_PORT}" ||
            test "${_prevLdapsPort}" != "${LDAPS_PORT}" ||
            test "${_prevHttpsPort}" != "${HTTPS_PORT}" ; then
            echo_red "*****"
            echo_red "LDAP/LDAPS/HTTPS ports from original settings may not be changed on restart."
            echo_red "   Service         Original Setting     Attempt"
            echo_red "   LDAP_PORT       ${_prevLdapPort}                  ${LDAP_PORT}"
            echo_red "   LDAPS_PORT      ${_prevLdapsPort}                  ${LDAPS_PORT}"
            echo_red "   HTTPS_PORT      ${_prevHttpsPort}                  ${HTTPS_PORT}"
            echo_red "Please make any adjustments in dsconfig commands."
            echo_red "*****"
            container_failure 20 "Resolve the issues with your orchestration environment variables"
        fi
    fi

    echo "Generating ${_setupArgumentsFile}"
    cat <<EOSETUP > "${_setupArgumentsFile}"
    --verbose \
    --acceptLicense \
    --skipPortCheck \
    --instanceName ${INSTANCE_NAME} \
    --location ${LOCATION} \
    $(test ! -z "${LDAP_PORT}" && echo "--ldapPort ${LDAP_PORT}") \
    $(test ! -z "${LDAPS_PORT}" && echo "--ldapsPort ${LDAPS_PORT}") \
    $(test ! -z "${HTTPS_PORT}" && echo "--httpsPort ${HTTPS_PORT}") \
    --enableStartTLS \
    ${jvmOptions} \
    ${certificateOptions} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    ${_pingDataSetupArguments} \
    ${ADDITIONAL_SETUP_ARGS}
EOSETUP

}

#
getPingDataInstanceName ()
{
    if test "${RUN_PLAN}" = "RESTART" ; then
        grep "ds-cfg-instance-name: " "${_configLDIF}" | awk -F": " '{ print $2 }'
    else
        hostname
    fi
}
