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
if test "${PD_STATE}" = "GENESIS" ; then
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

if test -n "${PING_IDENTITY_PASSWORD}";
then 
    if ! test -f "${ROOT_USER_PASSWORD_FILE}" ;
    then
        mkdir -p "$( dirname "${ROOT_USER_PASSWORD_FILE}" )"
        echo "${PING_IDENTITY_PASSWORD}" > "${ROOT_USER_PASSWORD_FILE}"
    fi
    if ! test -f "${ENCRYPTION_PASSWORD_FILE}" ;
    then
        mkdir -p "$( dirname "${ENCRYPTION_PASSWORD_FILE}" )"
        echo "${PING_IDENTITY_PASSWORD}" > "${ENCRYPTION_PASSWORD_FILE}"
    fi
    if ! test -f "${ADMIN_USER_PASSWORD_FILE}" ;
    then
        mkdir -p "$( dirname "${ADMIN_USER_PASSWORD_FILE}" )"
        echo "${PING_IDENTITY_PASSWORD}" > "${ADMIN_USER_PASSWORD_FILE}"
    fi
fi
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
