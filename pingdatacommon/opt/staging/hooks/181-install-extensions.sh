#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

EXTENSIONS_DIR="${STAGING_DIR}/extensions"
PROFILE_EXTENSIONS_DIR="${PD_PROFILE}/server-sdk-extensions"

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

    extensionID=0
    for remoteInstallFile in $(find ${EXTENSIONS_DIR} -type f -name \*remote.list ) ; 
    do
        if test -n "${remoteInstallFile}" && test -f "${remoteInstallFile}" ; then
            while IFS=" " read -r extensionUrl extensionSignatureUrl keyServer keyID || test -n "${extensionUrl}" ;
            do
                extensionID=$(( extensionID + 1 ))
                printf "Extension URL: %s - extension Signature URL: %s - GPG repo: %s - GPG key: %s\n" "${extensionUrl}" "${extensionSignatureUrl}" "${keyServer}" "${keyID}"
                tmpDir="$( mktemp -d )"
                ( cd "${tmpDir}" && curl -sSo extension-${extensionID}.zip "${extensionUrl}" )
                extensionFile=$(ls -1tr "${tmpDir}" | tail -1 )
                
                export GNUPGHOME="${tmpDir}"
                if test -n "${extensionSignatureUrl}" ; then
                    ( cd "${tmpDir}" && curl -sSLO "${extensionSignatureUrl}" )
                    extensionSignatureFile=$(ls -1tr "${tmpDir}" | tail -1 )
                    if test -n "${keyServer}" && test -n "${keyID}" ; then
                        signatureMatched=false
                        gpg --batch --keyserver "${keyServer}" --recv-keys "${keyID}"
                        gpg --batch --verify "${tmpDir}/${extensionSignatureFile}" "${tmpDir}/${extensionFile}"
                        if test ${?} -eq 0 ; then
                            signatureMatched=true
                        fi
                        gpgconf --kill all
                        if ! test ${signatureMatched} ; then
                            echo_red "The PGP signature for ${extensionUrl} did not match. Skipping..."
                            continue
                        fi
                        echo_green "The PGP signature for ${extensionUrl} matched."
                    else
                        extensionRemoteSignature=$( cat "${extensionSignatureFile}" )
                        extensionLocalSignature=$( sha1sum "${extensionFile}" | awk '{print $1}' )
                        if ! test "${extensionRemoteSignature}" = "${extensionLocalSignature}" ; then
                            echo_red "The SHA1 signature for ${extensionUrl} did not match. Skipping..."
                            continue
                        fi
                        echo_green "The SHA1 signature for ${extensionUrl} matched."
                    fi
                else
                    if ! test ${ENABLE_INSECURE_REMOTE_EXTENSIONS:-false} ; then
                        continue
                    fi
                fi

                mkdir -p "${PROFILE_EXTENSIONS_DIR}"
                cp "${tmpDir}/${extensionFile}" "${PROFILE_EXTENSIONS_DIR}"/
            done < "${remoteInstallFile}"
        fi
    done

    # FIXME: when all PingData products have been updated to use manage-profile, this block may be removed.
    # This is required for PingData products that do not use manage-profile yet.
    if test ! "${PING_PRODUCT}" = 'PingDirectory'; then
        if test -d "${PROFILE_EXTENSIONS_DIR}" && find "${PROFILE_EXTENSIONS_DIR}" -type f -name \*.zip | read; then
            # shellcheck disable=SC2045
            for extension in $(ls -1 "${PROFILE_EXTENSIONS_DIR}/"*.zip); do
                "${SERVER_ROOT_DIR}/bin/manage-extension" --install "${extension}" --no-prompt
            done
        fi
    fi
fi

