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

    REMOTE_INSTALL_FILE="${EXTENSIONS_DIR}/remote.list"
    if test -f "${REMOTE_INSTALL_FILE}" ; then
        while IFS=" " read -r extensionUrl extensionSignatureUrl keyServer keyID ;
        do
            printf "Extension URL: %s - extension Signature URL: %s - GPG repo: %s - GPG key: %s\n" "${extensionUrl}" "${extensionSignatureUrl}" "${keyServer}" "${keyID}"
            tmpDir="/tmp/extension-$((RANDOM * RANDOM))"
            rm -rf ${tmpDir}
            mkdir ${tmpDir}
            curl -sS ${extensionUrl}
            export GNUPGHOME="${tmpDir}"
            if test -n "${keyServer}" && test -n "${keyID}" ; then
                gpg --batch --keyserver ${keyServer} --recv-keys ${keyID}
                gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu
                gpgconf --kill all
            fi
        done < ${REMOTE_INSTALL_FILE}
    fi

    if ! test -z "$( ls -A "${STAGING_DIR}/extensions/"*.zip 2>/dev/null )" ; then
        # shellcheck disable=SC2045
        for extension in $( ls -1 "${STAGING_DIR}/extensions/"*.zip ) ; do 
            "${SERVER_ROOT_DIR}/bin/manage-extension" --install "${extension}" --no-prompt
        done
    fi
fi

