#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=../pingcommon/lib.sh
. "${BASE}/lib.sh"

# shellcheck source=../pingdatacommon/pingdata.lib.sh
test -f "${BASE}/pingdata.lib.sh" && . "${BASE}/pingdata.lib.sh"

certificateOptions=$( getCertificateOptions )

encryptionOption="--encryptDataWithRandomPassphrase"
if test -f "${ENCRYPTION_PASSWORD_FILE}" ; then
    encryptionOption="--encryptDataWithPassphraseFromFile ${ENCRYPTION_PASSWORD_FILE}"
fi

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

# using ${HOSTNAME} always works on Docker
# the ports variables don't need to be quoted they never have whitespaces
# shellcheck disable=SC2039,SC2086
"${SERVER_ROOT_DIR}"/setup \
    --no-prompt \
    --verbose \
    --acceptLicense \
    --instanceName "${HOSTNAME}" \
    --location "${LOCATION}" \
    --skipPortCheck \
    --ldapPort ${LDAP_PORT} \
    --ldapsPort ${LDAPS_PORT} \
    --httpsPort ${HTTPS_PORT} \
    --enableStartTLS \
    ${jvmOptions} \
    ${certificateOptions} \
    ${encryptionOption} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --baseDN "${USER_BASE_DN}" \
    --addBaseEntry \
    --doNotStart 2>&1

die_on_error 77 "Instance setup unsuccessful"
