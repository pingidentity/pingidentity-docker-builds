#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x

# shellcheck source=/dev/null
test -f "${CONTAINER_ENV}" && . "${CONTAINER_ENV}"

if test -f "${BASE}/liveness.sh"; then
    sh "${BASE}/liveness.sh"

    exit $?
fi

exit 0
