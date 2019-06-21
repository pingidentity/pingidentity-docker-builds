#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../pingcommon/lib.sh
. "${BASE}/lib.sh"

# shellcheck source=../pingdatacommon/pingdata.lib.sh
test -f "${BASE}/pingdata.lib.sh" && . "${BASE}/pingdata.lib.sh"

# We might need this stuff below 
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

export certificateOptions encryptionOption jvmOptions 

# run the manage-profile to setup the server
"${SERVER_ROOT_DIR}"/bin/manage-profile setup \
    --profile "${STAGING_DIR}/pd.profile" \
    --profileVariablesFile "${STAGING_DIR}/env_vars" \
    --useEnvironmentVariables \
    --tempProfileDirectory "/tmp" \
    --doNotStart
