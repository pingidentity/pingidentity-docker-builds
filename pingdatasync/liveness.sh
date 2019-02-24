#!/user/bin/env sh
ldapsearch -p ${LDAPS_PORT} -Z -X -b "cn=monitor" -s base "(&)" || exit 1