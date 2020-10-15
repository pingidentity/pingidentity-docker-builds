#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

#
# Build the password file options
#
buildPasswordFileOptions

#
# Build certification options
#
certificateOptions=$( getCertificateOptions )
_returnCode=${?}
if test ${_returnCode} -ne 0 ; then
    echo_red "${certificateOptions}"
    container_failure 183 "Invalid certificate options"
fi

#
# Build encryption option.
#
encryptionOption=$( getEncryptionOption )
_returnCode=${?}
if test ${_returnCode} -ne 0 ; then
    echo_red "${encryptionOption}"
    container_failure 183 "Invalid encryption option"
fi

#
# Build jvm options.
#
jvmOptions=$( getJvmOptions )
_returnCode=${?}
if test ${_returnCode} -ne 0 ; then
    echo_red "${jvmOptions}"
    container_failure 183 "Invalid JVM options"
fi

export certificateOptions encryptionOption jvmOptions

# Test to see if a Ping Data profile (i.e. pd.profile) is found.  If not, create it

test -d "${PD_PROFILE}" || mkdir -p "${PD_PROFILE}"

# If a dsconfig directory is found in the STAGING_DIR create some error text and fail the
# container.

if test -d "${STAGING_DIR}/dsconfig"; then
    echo_red "*****"
    echo_red "A legacy server-profile with a top level 'dsconfig' directory was found."
    echo_red "Please remove or move these configurations into a 'pd.profile/dsconfig'"
    echo_red "directory in your server-profile."
    echo_red "*****"
    container_failure 183 "Resolve the location of your dsconfig directory in server-profile"
fi

# If the a setup-arguments.txt file isn't found, then generate
_isSetupArgumentsGenerated=false
if test ! -f "${_setupArgumentsFile}"; then
    generateSetupArguments
    _isSetupArgumentsGenerated=true
fi

# run the manage-profile to setup the server
echo "Running manage_profile setup ....."
_manage_profile_cmd="${SERVER_ROOT_DIR}/bin/manage-profile setup \
    --profile ${PD_PROFILE} \
    --useEnvironmentVariables \
    --tempProfileDirectory /tmp \
    --doNotStart \
    ${_pingDataManageProfileSetupArgs}"

echo "  ${_manage_profile_cmd}"

${_manage_profile_cmd}
_manageProfileRC=$?

# Delete the generated setup-arguments.txt file from the profile
if test "${_isSetupArgumentsGenerated}" = "true"; then
    rm "${_setupArgumentsFile}"
fi

if test ${_manageProfileRC} -ne 0 ; then
    test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif
    echo_red "Error during 'manage-profile setup'"
    echo_red "Log '${SERVER_ROOT_DIR}/logs/tools/manage-profile.log'"
    cat "${SERVER_ROOT_DIR}/logs/tools/manage-profile.log"
    echo_red "Log '${SERVER_ROOT_DIR}/logs/tools/install-ds.log'"
    cat "${SERVER_ROOT_DIR}/logs/tools/install-ds.log"
    exit 183
fi
