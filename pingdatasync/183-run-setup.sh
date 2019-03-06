#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=../pingdatacommon/pingdata.lib.sh
test -f "${BASE}/pingdata.lib.sh" && . "${BASE}/pingdata.lib.sh"

certificateOptions=$( getCertificateOptions )

jvmOptions=""
if ! test "${MAX_HEAP_SIZE}" = "AUTO" ; then
    jvmOptions="--maxHeapSize ${MAX_HEAP_SIZE}"
fi
case "${JVM_TUNING}" in
    NONE|AGGRESSIVE|SEMI_AGGRESSIVE)
        jvmOptions="${jvmOptions} --jvmTuningParameter ${JVM_TUNING}"
        ;;
    *)
        echo "**********"
        echo "Unsupported JVM_TUNING value [${JVM_TUNING}]"
        echo "Value must be NONE, AGGRESSIVE or SEMI_AGGRESSIVE"
        exit 75
        ;;
esac

# shellcheck disable=SC2039,SC2086
"${SERVER_ROOT_DIR}"/setup \
    --no-prompt \
    --verbose \
    --acceptLicense \
    --instanceName "${HOSTNAME}" \
    --location "${LOCATION}" \
    --ldapPort ${LDAP_PORT} \
    --enableStartTLS \
    --ldapsPort ${LDAPS_PORT} \
    --httpsPort ${HTTPS_PORT} \
    ${certificateOptions} \
    ${jvmOptions} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --doNotStart 2>&1
