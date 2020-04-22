#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../pingdatacommon/hooks/pingdata.lib.sh
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

#
# Build encryption option.
#
encryptionOption=$( getEncryptionOption )

#
# Build jvm options.
#
jvmOptions=$( getJvmOptions )

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


# If there isn't a setup-arguments.txt file, then we will create one based on the variables provided

_setupArguments="${PD_PROFILE}/setup-arguments.txt"

# Create product specfic setup arguments and manage-profile setup arguments
case "${PING_PRODUCT}" in
    PingDataSync|PingDataGovernance|PingDirectoryProxy)
        _pingDataSetupArguments=""
        _pingDataManageProfileSetupArgs=""
        ;;
    PingDirectory)
        _pingDataSetupArguments="${encryptionOption} \
                                 --baseDN \"${USER_BASE_DN}\" \
                                 --addBaseEntry"
        _pingDataManageProfileSetupArgs="--rejectFile /tmp/rejects.ldif ${_skipImports}"
        ;;
    *)
        echo_red "Unknown PING_PRODUCT value [${PING_PRODUCT}]"
        exit 182
        ;;
esac

if test ! -f "${_setupArguments}"; then
    echo "Generating ${_setupArguments}"
    cat <<EOSETUP > "${_setupArguments}"
    --verbose \
    --acceptLicense \
    --skipPortCheck \
    --instanceName ${INSTANCE_NAME} \
    --location ${LOCATION} \
    $(test ! -z "${LDAP_PORT}" && echo "--ldapPort ${LDAP_PORT}") \
    $(test ! -z "${LDAPS_PORT}" && echo "--ldapsPort ${LDAPS_PORT}") \
    $(test ! -z "${HTTPS_PORT}" && echo "--httpsPort ${HTTPS_PORT}") \
    --enableStartTLS \
    ${jvmOptions} \
    ${certificateOptions} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    ${_pingDataSetupArguments} \
    ${ADDITIONAL_SETUP_ARGS}
EOSETUP

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

$_manage_profile_cmd

if test $? -ne 0 ; then
    test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif
    echo_red "Error during 'manage-profile setup'"
    exit 183
fi
