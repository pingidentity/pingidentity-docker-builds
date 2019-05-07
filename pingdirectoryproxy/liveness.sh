#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

# shellcheck disable=SC2086
ldapsearch --dontWrap --terse --suppressPropertiesFileComment --operationPurpose "Docker container liveness check" -p ${LDAPS_PORT} -Z -X -b "${USER_BASE_DN}" -s base "(&)" 1.1 2>/dev/null || exit 1
