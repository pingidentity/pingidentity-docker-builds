#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

getCertificateOptions ()
{
    # Validate keystore options
    if test -n "${KEYSTORE_FILE}" ; then
        if ! test -f "${KEYSTORE_FILE}"; then
            echo_red "**********"
            echo_red "KEYSTORE_FILE value [${KEYSTORE_FILE}] is invalid: the specified file does not exist"
            exit 75
        fi
        if test -z "${KEYSTORE_PIN_FILE}" ; then
            echo_red "**********"
            echo_red "A value for KEYSTORE_PIN_FILE must be specified when KEYSTORE_FILE is provided"
            exit 75
        fi
        if ! test -f "${KEYSTORE_PIN_FILE}"; then
            echo_red "**********"
            echo_red "KEYSTORE_PIN_FILE value [${KEYSTORE_PIN_FILE}] is invalid: the specified file does not exist"
            exit 75
        fi
        if test -z "${KEYSTORE_TYPE}" ; then
            # Attempt to get the keystore type from the keystore file name
            _keystoreFileLower=$( toLower "${KEYSTORE_FILE}" )
            case "${_keystoreFileLower}" in
                *.p12)
                    KEYSTORE_TYPE="pkcs12"
                    ;;
                *)
                    # No KEYSTORE_TYPE is set. Defaulting to JKS
                    KEYSTORE_TYPE="jks"
                    ;;
            esac
        else
            # default to JKS
            KEYSTORE_TYPE=$( toLower "${KEYSTORE_TYPE:jks}" )
            case "${KEYSTORE_TYPE}" in
                pkcs12|jks)
                    ;;
                *)
                    echo_red "**********"
                    echo_red "Unsupported KEYSTORE_TYPE value [${KEYSTORE_TYPE}]"
                    echo_red "Value must be PKCS12 or JKS"
                    exit 75
                    ;;
            esac
        fi
    else
        KEYSTORE_PIN_FILE="${SERVER_ROOT_DIR}/config/keystore.pin"
        if test -f "${SERVER_ROOT_DIR}/config/keystore" && test -f "${SERVER_ROOT_DIR}/config/keystore.pin" ; then
            KEYSTORE_FILE="${SERVER_ROOT_DIR}/config/keystore"
            KEYSTORE_TYPE="jks"
        elif test -f "${SERVER_ROOT_DIR}/config/keystore.p12" && test -f "${SERVER_ROOT_DIR}/config/keystore.pin" ; then
            KEYSTORE_FILE="${SERVER_ROOT_DIR}/config/keystore.p12"
            KEYSTORE_TYPE="pkcs12"
        fi
    fi

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
        certificateOptions="${certificateOptions} --keyStorePasswordFile ${KEYSTORE_PIN_FILE}"
    fi

    # Validate truststore options
    if test -n "${TRUSTSTORE_FILE}" ; then
        if ! test -f "${TRUSTSTORE_FILE}"; then
            echo_red "**********"
            echo_red "TRUSTSTORE_FILE value [${TRUSTSTORE_FILE}] is invalid: the specified file does not exist"
            exit 75
        fi
        if test -n "${TRUSTSTORE_PIN_FILE}" && ! test -f "${TRUSTSTORE_PIN_FILE}"; then
            echo_red "**********"
            echo_red "TRUSTSTORE_PIN_FILE value [${TRUSTSTORE_PIN_FILE}] is invalid: the specified file does not exist"
            exit 75
        fi
        if test -z "${TRUSTSTORE_TYPE}" ; then
            # Attempt to get the truststore type from the truststore file name
            _truststoreFileLower=$( toLower "${TRUSTSTORE_FILE}" )
            case "${_truststoreFileLower}" in
                *.p12)
                    TRUSTSTORE_TYPE="pkcs12"
                    ;;
                *)
                    # No TRUSTSTORE_TYPE is set. Defaulting to JKS
                    TRUSTSTORE_TYPE="jks"
                    ;;
            esac
        else
            # default to JKS
            TRUSTSTORE_TYPE=$( toLower "${TRUSTSTORE_TYPE:jks}" )
            case "${TRUSTSTORE_TYPE}" in
                pkcs12|jks)
                    ;;
                *)
                    echo_red "**********"
                    echo_red "Unsupported TRUSTSTORE_TYPE value [${TRUSTSTORE_TYPE}]"
                    echo_red "Value must be PKCS12 or JKS"
                    exit 75
                    ;;
            esac
        fi
    else
        if test -f "${SERVER_ROOT_DIR}/config/truststore" ; then
            TRUSTSTORE_FILE="${SERVER_ROOT_DIR}/config/truststore"
            TRUSTSTORE_TYPE="jks"
        elif test -f "${SERVER_ROOT_DIR}/config/truststore.p12" ; then
            TRUSTSTORE_FILE="${SERVER_ROOT_DIR}/config/truststore.p12"
            TRUSTSTORE_TYPE="pkcs12"
        fi
        if test -f "${SERVER_ROOT_DIR}/config/truststore.pin" ; then
            TRUSTSTORE_PIN_FILE="${SERVER_ROOT_DIR}/config/truststore.pin"
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

getJvmOptions ()
{
    jvmOptions=""
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
    echo "${jvmOptions}"
}

