#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=/dev/null
test -f "${CONTAINER_ENV}" && . "${CONTAINER_ENV}"

# shellcheck disable=SC2086
ldapsearch \
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
    2>/dev/null || exit 1
