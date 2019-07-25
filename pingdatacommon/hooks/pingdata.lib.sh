#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

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

