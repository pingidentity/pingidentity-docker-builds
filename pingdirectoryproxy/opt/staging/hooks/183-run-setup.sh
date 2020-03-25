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

# This INSTANCE_NAME must be unique across all instances, hence the addition
# of the K8S Cluster Name. This should be used in the PingDirectoryProxy profile
# setup-arguments.txt

export INSTANCE_NAME="${_podInstanceName}"

# TODO - Maybe allow for an ENV_VARS variable specifying a file (default to "${STAGING_DIR}/env_vars")

if test -f "${STAGING_DIR}/env_vars"  ; then
    _manageProfileOptions="--profileVariablesFile ${STAGING_DIR}/env_vars "
fi

# GDO-57 - If there isn't a setup-arguments.txt file, then we will create one based on the
#          variables provided
test -d "${PD_PROFILE}" || mkdir -p "${PD_PROFILE}"
_setupArguments="${PD_PROFILE}/setup-arguments.txt"
if test ! -f "${_setupArguments}"; then
    echo "Generating ${_setupArguments}"
    cat <<EOSETUP > "${_setupArguments}"
    --verbose \
    --acceptLicense \
    --skipPortCheck \
    --instanceName ${INSTANCE_NAME} \
    --location ${LOCATION} \
    ${LDAP_PORT:+--ldapPort ${LDAP_PORT}} \
    ${LDAPS_PORT:+--ldapsPort ${LDAPS_PORT}} \
    ${HTTPS_PORT:+--httpsPort ${HTTPS_PORT}} \
    --enableStartTLS \
    ${jvmOptions} \
    ${certificateOptions} \
    ${encryptionOption} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}"
EOSETUP

fi

# run the manage-profile to setup the server
"${SERVER_ROOT_DIR}"/bin/manage-profile setup \
    --profile "${PD_PROFILE}" \
    --useEnvironmentVariables \
    --tempProfileDirectory "/tmp" \
    --doNotStart \
    ${_manageProfileOptions}

if test ${?} -ne 0 ; then
    exit 183
fi