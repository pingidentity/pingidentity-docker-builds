#!/usr/bin/env sh
set -x

# shellcheck disable=SC2086
ldapsearch -p ${LDAPS_PORT} -Z -X -b "" -s base "(&)"
