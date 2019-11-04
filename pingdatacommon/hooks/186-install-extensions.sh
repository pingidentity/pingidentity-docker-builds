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

    for remoteInstallFile in $(find ${EXTENSIONS_DIR} -type f -name \*.remote.list ) ; 
    do
        
        if test -f "${remoteInstallFile}" ; then
            while IFS=" " read -r extensionUrl extensionSignatureUrl keyServer keyID ;
            do
                printf "Extension URL: %s - extension Signature URL: %s - GPG repo: %s - GPG key: %s\n" "${extensionUrl}" "${extensionSignatureUrl}" "${keyServer}" "${keyID}"
                tmpDir="/tmp/extension-$((RANDOM * RANDOM))"
                rm -rf ${tmpDir}
                mkdir ${tmpDir}
                ( cd ${tmpDir} && curl -sSO ${extensionUrl} )
                extensionFile=$(ls -1tr ${tmpDir} | tail -1 )
                
                export GNUPGHOME="${tmpDir}"
                if test -n "${extensionSignatureUrl}" ; then
                    ( cd ${tmpDir} && curl -sSO ${extensionSignatureUrl} )
                    extensionSignatureFile=$(ls -1tr ${tmpDir} | tail -1 )
                    if test -n "${keyServer}" && test -n "${keyID}" ; then
                        gpg --batch --keyserver ${keyServer} --recv-keys ${keyID}
                        gpg --batch --verify ${extensionSignatureFile} ${extensionFile}
                        gpgconf --kill all
                    else
                        extensionRemoteSignature=$(cat ${extensionSignatureFile})
                        extensionLocalSignature=$( sha1sum ${extensionFile} | awk '{print $1}' )
                        test "${extensionRemoteSignature}" = "${extensionLocalSignature}"
                    fi
                else
                    if ! test ${ENABLE_INSECURE_REMOTE_EXTENSIONS} ; then
                        continue
                    fi
                fi
                cp ${extensionFile} ${EXTENSIONS_DIR}
            done < ${remoteInstallFile}
        fi
    done

    if find "${EXTENSIONS_DIR}" -type f -name \*.zip | read ; then
        # shellcheck disable=SC2045
        for extension in $( ls -1 "${STAGING_DIR}/extensions/"*.zip ) ; do 
            "${SERVER_ROOT_DIR}/bin/manage-extension" --install "${extension}" --no-prompt
        done
    fi
fi

