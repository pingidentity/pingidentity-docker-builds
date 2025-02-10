#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x

# shellcheck source=/dev/null
test -f "${CONTAINER_ENV}" && . "${CONTAINER_ENV}"

# Use first parameter as timeout and set to 1 as default
TIMEOUT="${1:-1}"

URL="https://localhost:${HTTPS_PORT}/available-or-degraded-state"

for _ in $(seq "${TIMEOUT}"); do

    _curlResult=$(curl -k -o /dev/null -w '%{http_code}' --connect-timeout 2 "${URL}" 2> /dev/null)

    if test "${_curlResult}" -eq 200; then
        exit 0
    fi

    sleep 1
done

exit 1
