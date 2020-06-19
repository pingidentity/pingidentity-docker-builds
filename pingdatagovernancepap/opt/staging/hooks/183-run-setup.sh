#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
test -f "${HOOKS_DIR}/pingdata.lib.sh" && . "${HOOKS_DIR}/pingdata.lib.sh"

# Move license to current location
# cp "${LICENSE_DIR}/${LICENSE_FILE_NAME}" .

# shellcheck disable=SC2039,SC2086
if ! test -f "${SERVER_ROOT_DIR}/config/configuration.yml" ;
then

  # TODO: osha - Remove the admin username/passwords
  #   once DS-42383 is merged (presumably in 8.2-EA)
  _build_info="${SERVER_ROOT_DIR}/build-info.txt"
  if test -f "${_build_info}" \
    && awk \
'BEGIN {maj=0;min=0;ga=0}
$1=="Major" && $3=="8" {maj=1}
$1=="Minor" && $3=="1" {min=1}
$2=="Qualifier:" && $3=="-GA" {ga=1}
END {if (maj && min && ga) {exit 0} else {exit 1}}' \
    "${_build_info}";
  then
    "${SERVER_ROOT_DIR}"/bin/setup demo \
        --licenseKeyFile "${LICENSE_DIR}/${LICENSE_FILE_NAME}" \
        --dbAdminUsername "${PING_DB_ADMIN_USERNAME:-sa}" \
        --dbAdminPassword "${PING_DB_ADMIN_PASSWORD:-Symphonic2014!}" \
        --port ${HTTPS_PORT} \
        --hostname "${REST_API_HOSTNAME}" \
        --generateSelfSignedCertificate \
        --decisionPointSharedSecret "${DECISION_POINT_SHARED_SECRET}" \
        2>&1
  else
    "${SERVER_ROOT_DIR}"/bin/setup demo \
        --licenseKeyFile "${LICENSE_DIR}/${LICENSE_FILE_NAME}" \
        --port ${HTTPS_PORT} \
        --hostname "${REST_API_HOSTNAME}" \
        --generateSelfSignedCertificate \
        --decisionPointSharedSecret "${DECISION_POINT_SHARED_SECRET}" \
        2>&1
  fi
fi
