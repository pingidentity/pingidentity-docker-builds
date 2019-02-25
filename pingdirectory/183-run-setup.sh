#!/usr/bin/env sh
set -x

certificateOptions="--generateSelfSignedCertificate"
if test -f "${SERVER_ROOT_DIR}/config/keystore" && test -f "${SERVER_ROOT_DIR}/config/keystore.pin" ; then
    certificateOptions="--useJavaKeystore ${SERVER_ROOT_DIR}/config/keystore --keyStorePasswordFile ${SERVER_ROOT_DIR}/config/keystore.pin"
elif test -f "${SERVER_ROOT_DIR}/config/keystore.p12" && test -f "${SERVER_ROOT_DIR}/config/keystore.pin" ; then
    certificateOptions="--usePkcs12Keystore ${SERVER_ROOT_DIR}/config/keystore --keyStorePasswordFile ${SERVER_ROOT_DIR}/config/keystore.pin"
fi

if test -f "${SERVER_ROOT_DIR}/config/truststore" ; then
    certificateOptions="--useJavaTruststore ${SERVER_ROOT_DIR}/config/keystore"
elif test -f "${SERVER_ROOT_DIR}/config/truststore.p12" ; then
    certificateOptions="--usePkcs12Truststore ${SERVER_ROOT_DIR}/config/keystore"
fi
if test -f "${SERVER_ROOT_DIR}/config/truststore.pin" ; then
    certificateOptions="${certificateOptions} --trustStorePasswordFile ${SERVER_ROOT_DIR}/config/truststore.pin"
fi
certificateOptions="${certificateOptions} --certNickname ${CERTIFICATE_NICKNAME:-server-cert}"

encryptionArgument="--encryptDataWithRandomPassphrase"
if test -f "${ENCRYPTION_PASSWORD_FILE}" ; then
    encryptionArgument="--encryptDataWithPassphraseFromFile ${ENCRYPTION_PASSWORD_FILE}"
fi

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
    ${certificateOptions} \
    ${encryptionArgument} \
    --rootUserDN "${ROOT_USER_DN}" \
    --rootUserPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --baseDN "${USER_BASE_DN}" \
    --addBaseEntry \
    --doNotStart 2>&1

die_on_error 77 "Instance setup unsuccessful"
