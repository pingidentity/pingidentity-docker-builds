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
# If we are not the GENESIS server, we should remove the ldif files so they aren't 
# imported
#
if test "${PD_STATE}" != "GENESIS" ; then
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
