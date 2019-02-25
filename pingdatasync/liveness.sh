#!/user/bin/env sh
# shellcheck disable=SC2086
ldapsearch -p ${LDAPS_PORT} -Z -X -b "cn=monitor" -s base "(&)" || exit 1