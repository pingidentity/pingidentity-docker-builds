#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x

URL=$(eval echo "${1}")
TIMEOUT="${2:-1}"

echo "Wating for URL: ${URL}"
for _ in $(seq "${TIMEOUT}"); do

    _curlResult=$(curl -k -o /dev/null -w '%{http_code}' --connect-timeout 2 "${URL}" 2> /dev/null)

    if test "${_curlResult}" -eq 200; then
        exit 0
    fi

    echo "$_: Response: ${_curlResult} - ${URL}"

    sleep 1
done

exit 1
