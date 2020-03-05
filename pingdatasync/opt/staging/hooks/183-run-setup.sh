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

# shellcheck disable=SC2039,SC2086
"${SERVER_ROOT_DIR}"/setup \
    --no-prompt \
    --verbose \
    --acceptLicense \
    --instanceName "${HOSTNAME}" \
    --location "${LOCATION}" \
    --ldapPort ${LDAP_PORT} \
    --enableStartTLS \
    --ldapsPort ${LDAPS_PORT} \
    --httpsPort ${HTTPS_PORT} \
    ${certificateOptions} \
    ${jvmOptions} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --doNotStart 2>&1
