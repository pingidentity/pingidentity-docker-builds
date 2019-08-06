#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

URL="https://localhost:${HTTPS_PORT}/available-or-degraded-state"

_curlResult=$(curl -k -o /dev/null -w '%{http_code}' "${URL}" 2> /dev/null)

if test ${_curlResult} -ne 200 ; then
    # the health check must return 0 for healthy, 1 otherwise
    # but not any other code so we catch the curl return code and
    # change any non-zero code to 1
    # https://docs.docker.com/engine/reference/builder/#healthcheck
    exit 1
fi
