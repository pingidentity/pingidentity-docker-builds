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

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdirectory.lib.sh
. "${HOOKS_DIR}/pingdirectory.lib.sh"

echo "Restarting container"

#
# Generate the jvm options
#
jvmOptions=$(getJvmOptions)
_returnCode=${?}
if test ${_returnCode} -ne 0; then
    echo_red "${jvmOptions}"
    container_failure 183 "Invalid JVM options"
fi

# Before running any ds tools, remove java.properties and re-create it
# for the current JVM if necessary.
if ! compare_and_save_jvm_settings "${jvmOptions}" || test "${REGENERATE_JAVA_PROPERTIES}" = "true"; then
    echo "JVM options and/or JVM version have changed. Re-generating java.properties for current JVM."
    # re-initialize the current java.properties.  a backup in same location will be created.
    # Word-split is expected behavior for $jvmOptions. Disable shellcheck.
    # shellcheck disable=SC2086
    "${SERVER_ROOT_DIR}/bin/dsjavaproperties" --initialize ${jvmOptions}
else
    echo "JVM options and version have not changed. Will not generate a new java.properties file."
fi

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
        echo "PingDirectory instance version differs from licensed version. Querying license server."
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

_reimportDataValue="never"
if test "$(toLower "${PD_FORCE_DATA_REIMPORT}")" = "true"; then
    _reimportDataValue="always"
    PD_REBUILD_ON_RESTART="true"
fi

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
        --reimportData ${_reimportDataValue} \
        ${_licenseKeyFileArg} \
        ${_replaceFullProfile}"

echo "  ${_manage_profile_cmd}"

_replaceProfileOutputFile="/tmp/replace-profile-output.txt"
${_manage_profile_cmd} | tee "${_replaceProfileOutputFile}"
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

# Rebuild indexes if necessary
echo ""
if grep "there are no changes" "${_replaceProfileOutputFile}" > /dev/null; then
    echo "Indexes will not be rebuilt since there were no profile changes"
else
    echo "Rebuilding any new or untrusted indexes for base DN ${USER_BASE_DN}"
    rebuild-index --bulkRebuild new --bulkRebuild untrusted --baseDN "${USER_BASE_DN}"
fi
rm -f "${_replaceProfileOutputFile}"

# Set the server unavailable since there may be additional replication work
# to do before we can allow the server to respond correctly to a readiness.sh check.
#
# It is important to set the server back available during the 80-post-start.sh
# hook.
set_server_unavailable "Configuring replication" offline

exit 0
