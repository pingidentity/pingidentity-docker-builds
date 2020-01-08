#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../pingdatacommon/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# shellcheck disable=SC2039,SC2086
"${SERVER_ROOT_DIR}"/bin/setup demo \
    --licenseKeyFile "${LICENSE_DIR}/${LICENSE_FILE_NAME}" \
    --port ${HTTPS_PORT} \
    --hostname "${REST_API_HOSTNAME}" \
    --generateSelfSignedCertificate \
    2>&1
