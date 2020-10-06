#!/usr/bin/env sh
#
# Ping Identity DevOps - Ping Intelligence Liveness Check
#
${VERBOSE} && set -x

_livenessCheckResult=$(
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --output /dev/null \
        --request GET \
        https://localhost:8010/v4/ase \
        2>/dev/null
    )

if test "${_livenessCheckResult}" != "200"
then
    exit 1
fi

exit 0