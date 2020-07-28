#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# If there is a PING_IDENTITY_PASSWORD, create the possible PASSWORD_FILEs with that value if the
# file isn't already there
#
#   ROOT_USER_PASSWORDFILE
#   ENCRYPTION_PASSWORD_FILE
#   ADMIN_USER_PASSWORD_FILE

if test -n "${PING_IDENTITY_PASSWORD}";
then
    if test -n "${ROOT_USER_PASSWORD_FILE}" && ! test -f "${ROOT_USER_PASSWORD_FILE}" ;
    then
        mkdir -p "$( dirname "${ROOT_USER_PASSWORD_FILE}" )"
        echo "${PING_IDENTITY_PASSWORD}" > "${ROOT_USER_PASSWORD_FILE}"
    fi
    if test -n "${ENCRYPTION_PASSWORD_FILE}" && ! test -f "${ENCRYPTION_PASSWORD_FILE}" ;
    then
        mkdir -p "$( dirname "${ENCRYPTION_PASSWORD_FILE}" )"
        echo "${PING_IDENTITY_PASSWORD}" > "${ENCRYPTION_PASSWORD_FILE}"
    fi
    if test -n "${ADMIN_USER_PASSWORD_FILE}" && ! test -f "${ADMIN_USER_PASSWORD_FILE}" ;
    then
        mkdir -p "$( dirname "${ADMIN_USER_PASSWORD_FILE}" )"
        echo "${PING_IDENTITY_PASSWORD}" > "${ADMIN_USER_PASSWORD_FILE}"
    fi
fi

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
if test ! -f "${_setupArgumentsFile}"; then
    generateSetupArguments
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

if test $? -ne 0 ; then
    test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif
    echo_red "Error during 'manage-profile setup'"
    exit 183
fi
