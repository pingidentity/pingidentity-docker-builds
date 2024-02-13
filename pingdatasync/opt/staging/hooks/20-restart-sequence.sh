#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook is called when the container has been built in a prior startup
#- and a configuration has been found.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

echo "Restarting container"

update_java_properties_on_restart

# if this hook is provided it can be executed early on
run_hook "21-update-server-profile.sh"

# install any custom extensions provided
run_hook "181-install-extensions.sh"

appendTemplatesToVariablesIgnore

#
# Build the password file options
#
buildPasswordFileOptions

certificateOptions=$(getCertificateOptions)
_returnCode=${?}
if test ${_returnCode} -ne 0; then
    echo_red "${certificateOptions}"
    container_failure 183 "Invalid certificate options"
fi

#
# Generate the encryption options
#
encryptionOption=$(getEncryptionOption)
_returnCode=${?}
if test ${_returnCode} -ne 0; then
    echo_red "${encryptionOption}"
    container_failure 183 "Invalid encryption option"
fi

export certificateOptions encryptionOption jvmOptions

echo "Checking license file..."
_currentLicense="${SERVER_ROOT_DIR}/${LICENSE_FILE_NAME}"
_pdProfileLicense="${PD_PROFILE}/server-root/pre-setup/${LICENSE_FILE_NAME}"

if test ! -f "${_pdProfileLicense}"; then
    #check if license version differs from product version
    _currentLicenseVer=$(cat < "${_currentLicense}" | grep 'Version' | sed 's/Version=//g')
    if test "${LICENSE_VERSION}" != "${_currentLicenseVer}"; then
        echo "PingDataSync instance version differs from licensed version. Querying license server."
        #get a new license for the right version
        run_hook "17-check-license.sh"
    else
        echo "  Copying in license from existing install."
        echo "    ${_currentLicense} ==> "
        echo "      ${_pdProfileLicense}"
        # Create the pre-setup directory if it doesn't already exist
        mkdir -p "${PD_PROFILE}/server-root/pre-setup"
        cp -f "${_currentLicense}" "${_pdProfileLicense}"
    fi
else
    echo "Using new license from ${_pdProfileLicense}"
fi

if test -f "${_pdProfileLicense}"; then
    _licenseKeyFileArg="--licenseKeyFile ${_pdProfileLicense}"
fi

# If a setup-arguments.txt file isn't found, then generate
_isSetupArgumentsGenerated=false
if test ! -f "${SETUP_ARGUMENTS_FILE}"; then
    generateSetupArguments
    _isSetupArgumentsGenerated=true
fi

# Copy the manage-profile.log to a previous version to keep size down due to repeated fail attempts
mv "${SERVER_ROOT_DIR}/logs/tools/manage-profile.log" "${SERVER_ROOT_DIR}/logs/tools/manage-profile.log.prev"

case "$(toLower "${PD_REBUILD_ON_RESTART}")" in
    yes | true)
        echo "Forcing replace-profile due to PD_REBUILD_ON_RESTART=${PD_REBUILD_ON_RESTART} ..."
        _replaceFullProfile=" --replaceFullProfile"
        ;;
    *)
        echo "Merging changes from new server profile..."
        ;;
esac

_manage_profile_cmd="${SERVER_BITS_DIR}/bin/manage-profile replace-profile \
        --serverRoot ${SERVER_ROOT_DIR} \
        --profile ${PD_PROFILE} \
        --useEnvironmentVariables \
        ${_licenseKeyFileArg} \
        ${_replaceFullProfile}"

echo "  ${_manage_profile_cmd}"

${_manage_profile_cmd}
_manageProfileRC=$?

# Delete the generated setup-arguments.txt file from the profile
if test "${_isSetupArgumentsGenerated}" = "true"; then
    rm "${SETUP_ARGUMENTS_FILE}"
fi

if test ${_manageProfileRC} -ne 0; then
    echo_red "*****"
    echo_red "An error occurred during mange-profile replace-profile."
    echo_red "${SERVER_ROOT_DIR}/logs/tools/manage-profile.log listed below."
    echo_red "*****"

    cat "${SERVER_ROOT_DIR}/logs/tools/manage-profile.log"

    container_failure 20 "Resolve the issues with your server-profile"
fi

exit 0
