#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

EXTENSIONS_DIR="${STAGING_DIR}/extensions"
PROFILE_EXTENSIONS_DIR="${PD_PROFILE}/server-sdk-extensions"

if test -d "${EXTENSIONS_DIR}" ; 
then
    extensionID=0
    # shellcheck disable=SC2044
    for remoteInstallFile in $(find "${EXTENSIONS_DIR}" -type f -name \*remote.list ) ; 
    do
        if test -n "${remoteInstallFile}" && test -f "${remoteInstallFile}" ; then
            while IFS=" " read -r extensionUrl extensionSignatureUrl keyServer keyID || test -n "${extensionUrl}" ;
            do
                extensionID=$(( extensionID + 1 ))
                printf "Extension URL: %s - extension Signature URL: %s - GPG repo: %s - GPG key: %s\n" "${extensionUrl}" "${extensionSignatureUrl}" "${keyServer}" "${keyID}"
                tmpDir="$( mktemp -d )"
                extensionFile="${tmpDir}/extension-${extensionID}.zip"
                curl -sSLo "${extensionFile}" "${extensionUrl}"
                # extensionFile=$(ls -1tr "${tmpDir}" | tail -1 )
                
                export GNUPGHOME="${tmpDir}"
                if test -n "${extensionSignatureUrl}" ; then
                    extensionSignatureFile="${extensionFile}.signature"
                    curl -sSLo "${extensionSignatureFile}" "${extensionSignatureUrl}"
                    # extensionSignatureFile=$(ls -1tr "${tmpDir}" | tail -1 )
                    if test -n "${keyServer}" && test -n "${keyID}" ; then
                        signatureMatched=false
                        gpg --batch --keyserver "${keyServer}" --recv-keys "${keyID}"
                        gpg --batch --verify "${extensionSignatureFile}" "${extensionFile}"
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
                cp "${extensionFile}" "${PROFILE_EXTENSIONS_DIR}"/
                rm -rf "${tmpDir}"
            done < "${remoteInstallFile}"
        fi
    done
fi