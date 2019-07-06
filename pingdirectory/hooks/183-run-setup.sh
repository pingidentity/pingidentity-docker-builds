#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../pingdatacommon/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

#
# If we are the GENESIS state, then process any templates if they are defined.
#
if test "${PD_STATE}" == "GENESIS" ; then
    echo "PD_STATE is GENESIS ==> Processing Templates"
    
    LDIF_DIR="${STAGING_DIR}/pd.profile/ldif/userRoot"
    TEMPLATE_DIR="${LDIF_DIR}"
    test -z "${MAKELDIF_USERS}" && MAKELDIF_USERS=0

    for template in $( find "${TEMPLATE_DIR}" -type f -iname \*.template 2>/dev/null ) ; do 
            echo "Processing (${template}) template with ${MAKELDIF_USERS} users..."
            "${SERVER_ROOT_DIR}/bin/make-ldif" \
                --templateFile "${template}"  \
                --ldifFile "${template%.*}.ldif" \
                --numThreads 3
    done
else
    echo "PD_STATE is not GENESIS ==> Skipping Templates"
    echo "PD_STATE is not GENESIS ==> Will not process ldif imports"
    rm -rf "${STAGING_DIR}/pd.profile/ldif/*"
fi

# TODO - See the TODO in pingdata.lib.sh

#
# Build certification options
#
certificateOptions=$( getCertificateOptions )

#
# Build encryption option.
#
encryptionOption=$( getEncryptionOption )

#
# Build jvm options.
#
jvmOptions=$( getJvmOptions )

export certificateOptions encryptionOption jvmOptions 

# run the manage-profile to setup the server
# TODO Make pd.profile path a variable
"${SERVER_ROOT_DIR}"/bin/manage-profile setup \
    --profile "${STAGING_DIR}/pd.profile" \
    --profileVariablesFile "${STAGING_DIR}/env_vars" \
    --useEnvironmentVariables \
    --tempProfileDirectory "/tmp" \
    --doNotStart
