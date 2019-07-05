#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

EXTENSIONS_DIR="${STAGING_DIR}/extensions"
if test -d "${EXTENSIONS_DIR}" ; then
    AUTO_INSTALL_FILE="${EXTENSIONS_DIR}/autoinstall.list"
    if test -f "${AUTO_INSTALL_FILE}" ; then
        curl https://extensions.ping.directory/installer -o /tmp/installer
        chmod +x /tmp/installer 
        grep -v ^# "${AUTO_INSTALL_FILE}"  | while read -r extension ; do
            if test -n "${extension}" ; then
                /tmp/installer -I "${SERVER_ROOT_DIR}" -e "${extension}"
            fi
        done
    fi

    if ! test -z "$( ls -A "${STAGING_DIR}/extensions/"*.zip 2>/dev/null )" ; then
        # shellcheck disable=SC2045
        for extension in $( ls -1 "${STAGING_DIR}/extensions/"*.zip ) ; do 
            "${SERVER_ROOT_DIR}/bin/manage-extension" --install "${extension}" --no-prompt
        done
    fi
fi

