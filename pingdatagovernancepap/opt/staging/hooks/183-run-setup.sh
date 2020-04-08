#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../pingdatacommon/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# Move license to current location
# cp "${LICENSE_DIR}/${LICENSE_FILE_NAME}" .

# shellcheck disable=SC2039,SC2086
if ! test -f "${SERVER_ROOT_DIR}/config/configuration.yml" ;
then
    "${SERVER_ROOT_DIR}"/bin/setup demo \
        --licenseKeyFile "${LICENSE_DIR}/${LICENSE_FILE_NAME}" \
        --port ${HTTPS_PORT} \
        --hostname "${REST_API_HOSTNAME}" \
        --generateSelfSignedCertificate \
        --decisionPointSharedSecret "${DECISION_POINT_SHARED_SECRET}" \
        2>&1
fi
