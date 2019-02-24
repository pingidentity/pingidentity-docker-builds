#!/usr/bin/env sh
set -x

certificateOptions="      --generateSelfSignedCertificate"
if test -f "${SERVER_ROOT_DIR}/config/keystore" && test -f "${SERVER_ROOT_DIR}/config/keystore.pin" ; then
    certificateOptions="      --useJavaKeystore ${SERVER_ROOT_DIR}/config/keystore --keyStorePasswordFile ${SERVER_ROOT_DIR}/config/keystore.pin"
elif test -f "${SERVER_ROOT_DIR}/config/keystore.p12" && test -f "${SERVER_ROOT_DIR}/config/keystore.pin" ; then
    certificateOptions="      --usePkcs12Keystore ${SERVER_ROOT_DIR}/config/keystore --keyStorePasswordFile ${SERVER_ROOT_DIR}/config/keystore.pin"
fi

if test -f "${SERVER_ROOT_DIR}/config/truststore" ; then
    certificateOptions="      --useJavaTruststore ${SERVER_ROOT_DIR}/config/keystore"
elif test -f "${SERVER_ROOT_DIR}/config/truststore.p12" ; then
    certificateOptions="      --usePkcs12Truststore ${SERVER_ROOT_DIR}/config/keystore"
fi
if test -f "${SERVER_ROOT_DIR}/config/truststore.pin" ; then
    certificateOptions="${certificateOptions} --trustStorePasswordFile ${SERVER_ROOT_DIR}/config/truststore.pin"
fi
certificateOptions="${certificateOptions} --certNickname ${CERTIFICATE_NICKNAME}"

# shellcheck disable=SC2039,SC2086
"${SERVER_ROOT_DIR}"/setup \
    --no-prompt \
    --verbose \
    --acceptLicense \
    --instanceName "${HOSTNAME}" \
    --location "${LOCATION}" \
    --maxHeapSize "${MAX_HEAP_SIZE}" \
    --ldapPort ${LDAP_PORT} \
    --enableStartTLS \
    --ldapsPort ${LDAPS_PORT} \
    --httpsPort ${HTTPS_PORT} \
    --generateSelfSignedCertificate \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --doNotStart 2>&1
