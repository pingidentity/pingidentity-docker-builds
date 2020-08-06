#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# location of setup-arguments file used for PingData products
_setupArgumentsFile="${PD_PROFILE}/setup-arguments.txt"
_configLDIF="${SERVER_ROOT_DIR}/config/config.ldif"

#
# This is a helper function which will validate the certificate files and pins
#
# Example: Resulting validating the variables and files/pins for arg:
#
#   arg=keystore            arg=truststore
#       KEYSTORE_FILE           TRUSTSTORE_FILE
#       KEYSTORE_PIN_FILE       TRUSTSTORE_PIN_FILE
#       KEYSTORE_TYPE           TRUSTSTORE_TYPE
#
_validateCertificateOptions ()
{
    # certVar must be either keystore or truststore
    _certVar=$( toUpper "${1}" )
    _certVarLower=$( toLower "${1}" )

    _certFile="${_certVar}_FILE"
    _certPinFile="${_certVar}_PIN_FILE"
    _certType="${_certVar}_TYPE"

    _certFileVal=$( get_value "${_certFile}" )
    _certPinFileVal=$( get_value "${_certPinFile}" )
    _certTypeVal=$( get_value "${_certType}" )

    if test -n "${_certFileVal}" ; then
        if ! test -f "${_certFileVal}"; then
            echo_red "**********"
            echo_red "${_certFile} value [${_certFileVal}] is invalid: the specified file does not exist"
            exit 75
        fi
        if test -z "${_certPinFileVal}" ; then
            echo_red "**********"
            echo_red "A value for ${_certPinFile} must be specified when ${_certFile} is provided"
            exit 75
        fi
        if ! test -f "${_certPinFileVal}"; then
            echo_red "**********"
            echo_red "${_certPinFile} value [${_certPinFileVal}] is invalid: the specified file does not exist"
            exit 75
        fi
        if test -z "${_certTypeVal}" ; then
            # Attempt to get the store type from the store file name
            _storeFileLower=$( toLower "${_certFileVal}" )
            case "${_storeFileLower}" in
                *.p12)
                    eval "${_certType}=pkcs12"
                    ;;
                *)
                    # No KEYSTORE_TYPE is set. Defaulting to JKS
                    eval "${_certType}=jks"
                    ;;
            esac
        else
            # lowercase the truststore type
            _storeTypeLower=$( toLower "${_certTypeVal}" )
            case "${_storeTypeLower}" in
                pkcs12|jks)
                    eval "${_certType}=${_storeTypeLower}"
                    ;;
                *)
                    echo_red "**********"
                    echo_red "Unsupported ${_certType} value [${_certTypeVal}]"
                    echo_red "Value must be PKCS12 or JKS"
                    exit 75
                    ;;
            esac
        fi
    else
        if test -f "${SERVER_ROOT_DIR}/config/${_certVarLower}" && test -f "${SERVER_ROOT_DIR}/config/${_certVarLower}.pin" ; then
            eval "${_certFile}=${SERVER_ROOT_DIR}/config/${_certVarLower}"
            eval "${_certType}=jks"
        elif test -f "${SERVER_ROOT_DIR}/config/${_certVarLower}.p12" && test -f "${SERVER_ROOT_DIR}/config/${_certVarLower}.pin" ; then
            eval "${_certFile}=${SERVER_ROOT_DIR}/config/${_certVarLower}.p12"
            eval "${_certType}=pkcs12"
        fi

        if test -f "${SERVER_ROOT_DIR}/config/${_certVarLower}.pin" ; then
            eval "${_certPinFile}=${SERVER_ROOT_DIR}/config/${_certVarLower}.pin"
        fi
    fi
}

#
# Creates a set of certificate options useding during the setup and restart of a
# PingData product
#
# Options set will include some of the following depending on whether files and
# certificate names are included.:
#
#   generate certification if no keystore file provided
#     --generateSelfSignedCertificate
#
#   keystore info
#     --usePkcs12KeyStore {file}
#     --useJavaKeyStore {file}
#     --keyStorePasswordFile {file}
#
#   truststore info
#     --usePkcs12TrustStore {file}
#     --useJavaTrustStore {file}
#     --trustStorePasswordFile {file}
#
#   cerficate nickname used in keystore
#     --certNickname {nickname}
getCertificateOptions ()
{
    # Validate keystore options
    _validateCertificateOptions keystore
    _validateCertificateOptions truststore

    # Create the certificate options
    if test -z "${KEYSTORE_FILE}" ; then
        certificateOptions="--generateSelfSignedCertificate"
    else
        case "${KEYSTORE_TYPE}" in
            pkcs12)
                certificateOptions="--usePkcs12KeyStore ${KEYSTORE_FILE}"
                ;;
            jks)
                certificateOptions="--useJavaKeyStore ${KEYSTORE_FILE}"
                ;;
            *)
                ;;
        esac
        if test -n "${KEYSTORE_PIN_FILE}"; then
            certificateOptions="${certificateOptions} --keyStorePasswordFile ${KEYSTORE_PIN_FILE}"
        else
            echo_red "KEYSTORE_PIN_FILE is required if a KEYSTORE_FILE is provided."
            exit 75
        fi
    fi

    # Add the truststore certificate options
    if test -n "${TRUSTSTORE_FILE}" ; then
        case "${TRUSTSTORE_TYPE}" in
            pkcs12)
                certificateOptions="${certificateOptions} --usePkcs12TrustStore ${TRUSTSTORE_FILE}"
                ;;
            jks)
                certificateOptions="${certificateOptions} --useJavaTrustStore ${TRUSTSTORE_FILE}"
                ;;
            *)
                ;;
        esac
    fi
    if test -n "${TRUSTSTORE_PIN_FILE}"; then
        certificateOptions="${certificateOptions} --trustStorePasswordFile ${TRUSTSTORE_PIN_FILE}"
    fi

    # get the CERTIFICATE_NICKNAME. If not set, default to: server-cert
    certificateOptions="${certificateOptions} --certNickname ${CERTIFICATE_NICKNAME:-server-cert}"
    echo "${certificateOptions}"
}

# if an encryption password file is provided, then this will provide the option to use
# that file during setup.  Otherwise, a random passphrase will be used.
getEncryptionOption ()
{
    encryptionOption="--encryptDataWithRandomPassphrase"

    if test -f "${ENCRYPTION_PASSWORD_FILE}" ; then
        encryptionOption="--encryptDataWithPassphraseFromFile ${ENCRYPTION_PASSWORD_FILE}"
    fi

    echo "${encryptionOption}"
}

# returns a 1 if the product version of the image is 8.1 or higher
is_gte_81() {
  version=$(echo "${IMAGE_VERSION}" | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
  major=$(echo "${version}" | awk -F"." '{ print $1 }')
  minor=$(echo "${version}" | awk -F"." '{ print $2 }')
  if test "${major}" -eq 8 && test "${minor}" -ge 1 || test "${major}" -gt 8; then
    echo 1
  else
    echo 0
  fi
}

# returns the jvm option used during the setup of a PingData product
getJvmOptions ()
{
    jvmOptions=""
    origMaxHeapSize=""
    if test "$( is_gte_81 )" -eq 1 && test "${PING_PRODUCT}" = "PingDirectory"; then
        # If PingDirectory 8.1.0.0 or greater is run and the MAX_HEAP_SIZE is 384m, then it's
        # assumed to have never been set so it'll update it to the minimum needed
        # for version 8.1.0.0 or greater.
        if test "${MAX_HEAP_SIZE}" = "384m"; then
            origMaxHeapSize="${MAX_HEAP_SIZE}"
            MAX_HEAP_SIZE="768m"
        fi
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

    # If the original MAX_HEAP_SIZE was set, then it must have been manually set
    # ensure that it is maintained
    if test -n "${origMaxHeapSize}"; then
        MAX_HEAP_SIZE=${origMaxHeapSize}
    fi

    if test -n "${MAX_HEAP_SIZE}" && ! test "${MAX_HEAP_SIZE}" = "AUTO" ; then
        jvmOptions="${jvmOptions} --maxHeapSize ${MAX_HEAP_SIZE}"
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
            _pingDataManageProfileSetupArgs="${_pingDataManageProfileSetupArgs:+${_pingDataManageProfileSetupArgs} }--rejectFile /tmp/rejects.ldif ${_skipImports:=}"
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
