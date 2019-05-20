#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=../lib.sh
. "${BASE}/lib.sh"

"${BASE}/configure-tools.sh" \
        "${LDAP_PORT}" \
        "${ROOT_USER_DN}" \
        "${ROOT_USER_PASSWORD_FILE}" \
        "${ADMIN_USER_NAME}" \
        "${ADMIN_USER_PASSWORD_FILE}"