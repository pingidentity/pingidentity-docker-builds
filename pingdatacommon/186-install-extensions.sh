#!/usr/bin/env sh
set -x

if test -d "${STAGING_DIR}/extensions" && ! test -z "$( ls -A "${STAGING_DIR}/extensions/"*.zip 2>/dev/null )" ; then
    # shellcheck disable=SC2045
    for extension in $( ls -1 "${IN_DIR}/extensions/"*.zip ) ; do 
        "${SERVER_ROOT_DIR}/bin/manage-extension" --install "${extension}" --no-prompt
    done
fi