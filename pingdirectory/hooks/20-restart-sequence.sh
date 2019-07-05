#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook is called when the container has been built in a prior startup
#- and a configuration has been found.
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../pingdatacommon/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

echo "Restarting container"

# if this hook is provided it can be executed early on
run_hook "21-update-server-profile.sh"

# TODO - See the TODO in pingdata.lib.sh

certificateOptions=$( getCertificateOptions )

encryptionOption=$( getEncryptionOption )

jvmOptions=$( getJvmOptions )

export certificateOptions encryptionOption jvmOptions 

echo "Checking license file..."
_currentLicense="${LICENSE_DIR}/${LICENSE_FILE_NAME}"
_pdProfileLicense="${STAGING_DIR}/pd.profile/server-root/pre-setup/${LICENSE_FILE_NAME}"
if test ! -f "${_pdProfileLicense}" ; then
    echo "Copying in license from existing install."
    echo "  ${_currentLicense} ==> "
    echo "    ${_pdProfileLicense}"
    cp -af "${_currentLicense}" "${_pdProfileLicense}"
fi

echo "Merging changes from new server profile..."

"${SERVER_BITS_DIR}"/bin/manage-profile replace-profile \
        --serverRoot "${SERVER_ROOT_DIR}" \
        --profile "${STAGING_DIR}/pd.profile" \
        --useEnvironmentVariables

echo "  manage-profile replace-profile returned $?"
