#!/user/bin/env sh
# shellcheck disable=SC2086
ldapsearch -T --terse --suppressPropertiesFileComment -p ${LDAPS_PORT} -Z -X -b "cn=monitor" -s base "(&)" 2>/dev/null || exit 1