#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x

# shellcheck source=/dev/null
test -f "${CONTAINER_ENV}" && . "${CONTAINER_ENV}"

LDAPSEARCH_TIMEOUT_SECONDS=${LDAPSEARCH_TIMEOUT_SECONDS:-12}
timeout "${LDAPSEARCH_TIMEOUT_SECONDS}" ldapsearch \
    --dontWrap \
    --terse \
    --suppressPropertiesFileComment \
    --noPropertiesFile \
    --operationPurpose "Docker container liveness check" \
    --port "${LDAPS_PORT}" \
    --useSSL \
    --trustAll \
    --baseDN "" \
    --searchScope base "(&)" 1.1 \
    2> /dev/null || exit 1
