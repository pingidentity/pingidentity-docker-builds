#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# TODO Make pd.profile path a variable
PD_PROFILE="${STAGING_DIR}/pd.profile"

# shellcheck source=../../pingdatacommon/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

#
# If we are the GENESIS state, then process any templates if they are defined.
#
if test "${PD_STATE}" == "GENESIS" ; then
    echo "PD_STATE is GENESIS ==> Processing Templates"
    
    # TODO need to process all ldif subdirectories, not just userRoot
    LDIF_DIR="${PD_PROFILE}/ldif/userRoot"
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
    _skipImports="--skipImportLdif "
fi

#
# Due to an issue with the manage-profile process, we need to install the extensions before we 
# setup, so the dsconfig command can properly configure the extension.
# So we will do that with the server root prior to manage-profile
#
EXTENSION_DIR="${PD_PROFILE}/server-sdk-extensions"
if test -d "${EXTENSION_DIR}" ; then
    echo "Processing extensions in ${EXTENSION_DIR}..."
    for _extension in $( find "${EXTENSION_DIR}" -mindepth 1 -maxdepth 1 2> /dev/null ) ; do
        "${SERVER_ROOT_DIR}"/bin/manage-extension \
            --install "${_extension}" \
            --no-prompt

        rm -rf "${_extension}"
    done
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

# This INSTANCE_NAME must be unique across all instances, hence the addition
# of the K8S Cluster Name. This should be used in the PingDirectory profile
# setup-arguments.txt

export INSTANCE_NAME="${_podInstanceName}"

# TODO - Maybe allow for an ENV_VARS variable specifying a file (default to "${STAGING_DIR}/env_vars")

if test -f "${STAGING_DIR}/env_vars"  ; then
    _manageProfileOptions="--profileVariablesFile ${STAGING_DIR}/env_vars "
fi

# GDO-57 - If there isn't a setup-arguments.txt file, then we will create one based on the
#          variables provided
_setupArguments="${PD_PROFILE}/setup-arguments.txt"
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
    ${encryptionOption} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --baseDN "${USER_BASE_DN}" \
    --addBaseEntry
EOSETUP

fi

# run the manage-profile to setup the server
"${SERVER_ROOT_DIR}"/bin/manage-profile setup \
    --profile "${PD_PROFILE}" \
    --useEnvironmentVariables \
    --tempProfileDirectory "/tmp" \
    --doNotStart \
    --rejectFile /tmp/rejects.ldif \
    ${_manageProfileOptions} \
    ${_skipImports}

if test $? -ne 0 ; then
    test -f /tmp/rejects.ldif && cat /tmp/rejects.ldif
    exit 183
fi
