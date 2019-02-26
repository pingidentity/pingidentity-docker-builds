#!/usr/bin/env sh
set -x

# shellcheck disable=SC2086
ldapsearch -T --terse --suppressPropertiesFileComment -p ${LDAPS_PORT} -Z -X -b "${USER_BASE_DN}" -s base "(&)" 1.1 2>/dev/null || exit 1
