#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../pingcommon/lib.sh
. "${BASE}/lib.sh"

#
# TODO we need to pull this in earlier before manage-profile
#

# EXTENSIONS_DIR="${STAGING_DIR}/extensions"
# if test -d "${EXTENSIONS_DIR}" ; then
#    AUTO_INSTALL_FILE="${EXTENSIONS_DIR}/autoinstall.list"
#    if test -f "${AUTO_INSTALL_FILE}" ; then
#        curl https://extensions.ping.directory/installer -o /tmp/installer
#        chmod +x /tmp/installer 
#        grep -v ^# "${AUTO_INSTALL_FILE}"  | while read -r extension ; do
#            if test -n "${extension}" ; then
#                /tmp/installer -I "${SERVER_ROOT_DIR}" -e "${extension}"
#            fi
#        done
#    fi
#
#fi

