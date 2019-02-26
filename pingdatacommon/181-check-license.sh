#!/usr/bin/env sh
set -x
if ! test -f "${SERVER_ROOT_DIR}/${LICENSE_FILE_NAME}" ; then
    echo "License File absent"
    exit 89
fi  