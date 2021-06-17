#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

EXTENSIONS_DIR="${STAGING_DIR}/extensions"
PROFILE_EXTENSIONS_DIR="${PD_PROFILE}/server-sdk-extensions"

if test -d "${EXTENSIONS_DIR}"; then
    extensionID=0

    # Create tmp directory to hold temporary zip and signature files
    _tmpExtDir="$(mktemp -d)"

    find "${EXTENSIONS_DIR}" -type f -name \*remote.list ! -name "$(printf "*\n*")" > tmp
    while IFS= read -r remoteInstallFile; do
        if test -n "${remoteInstallFile}" && test -f "${remoteInstallFile}"; then
            while IFS=" " read -r extensionUrl extensionSignatureUrl keyServer keyID || test -n "${extensionUrl}"; do
                extensionID=$((extensionID + 1))
                echo "Extension #: ${extensionID}"
                echo "  Extension URL: ${extensionUrl}"
                echo "  Signature URL: ${extensionSignatureUrl:- --not set ---}"

                if test -n "${keyServer}" && test -n "${keyID}"; then
                    echo_yellow "################################################################################"
                    echo_yellow "################################################################################"
                    echo_yellow "################## WARNING - GPG SIGNATURE SUPPORT REMOVED #####################"
                    echo_yellow "#  Support for extension validation of a gpg signature with key server/id is    "
                    echo_yellow "#  no longer supported."
                    echo_yellow "#"
                    echo_yellow "#  Validating provided checksum signatures (.sha1), if provided, continues to be"
                    echo_yellow "#  supported."
                    echo_yellow "################################################################################"
                fi

                extensionFile="${_tmpExtDir}/extension-${extensionID}.zip"
                curl -sSLo "${extensionFile}" "${extensionUrl}"

                # TODO - Check for existence of URLs with .sha1, .sha256, .sha512 and depending on that existence
                #        check for those signatures. This would remove the need to specify the extensionSignatureUrl

                if test -n "${extensionSignatureUrl}"; then
                    extensionSignatureFile="${extensionFile}.signature"
                    curl -sSLo "${extensionSignatureFile}" "${extensionSignatureUrl}"

                    extensionRemoteSignature=$(cat "${extensionSignatureFile}")
                    extensionLocalSignature=$(sha1sum "${extensionFile}" | awk '{print $1}')
                    if ! test "${extensionRemoteSignature}" = "${extensionLocalSignature}"; then
                        echo_red "The SHA1 signature did not match. Skipping..."
                        continue
                    fi
                    echo_green "The SHA1 signature matched."
                else
                    if test "$(toLower "${ENABLE_INSECURE_REMOTE_EXTENSIONS:-false}")" = "false"; then
                        echo_red "The SHA1 signature not provided and insecure remote extensions are not allowed."
                        echo_red "  set 'ENABLE_INSECURE_REMOTE_EXTENSIONS=true' to allow.  Skipping..."
                        continue
                    else
                        echo_yellow "The SHA1 signature not provided however allowed 'ENABLE_INSECURE_REMOTE_EXTENSIONS=${ENABLE_INSECURE_REMOTE_EXTENSIONS}'"
                    fi
                fi

                mkdir -p "${PROFILE_EXTENSIONS_DIR}"
                cp "${extensionFile}" "${PROFILE_EXTENSIONS_DIR}"/
            done < "${remoteInstallFile}"
        fi
    done < tmp
    rm tmp

    # Cleanup temporary file
    rm -rf "${_tmpExtDir}"
fi
