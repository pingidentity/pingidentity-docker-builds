#!/usr/bin/env sh
FONT_RED='\033[0;31m'
FONT_GREEN='\033[0;32m'
FONT_NORMAL='\033[0m'
CHAR_CHECKMARK='\xE2\x9C\x94'
CHAR_CROSSMARK='\xE2\x9D\x8C'

################################################################################
# Echo message in red color
################################################################################
echo_red()
{
    echo -e "${FONT_RED}$*${FONT_NORMAL}"
}

################################################################################
# Echo message in green color
################################################################################
echo_green()
{
    echo -e "${FONT_GREEN}$*${FONT_NORMAL}"
}

_curl ()
{
    _httpResultCode=$( 
        curl \
            --get \
            --silent \
            --show-error \
            --write-out '%{http_code}' \
            --location \
            --connect-timeout 2 \
            --retry 6 \
            --retry-max-time 30 \
            --retry-connrefused \
            --retry-delay 3 \
            "${@}"
    )
    test ${_httpResultCode} -eq 200
    return ${?}
}


download_and_verify ()
{
	export GNUPGHOME="$(mktemp -d)" 
    TMP_VS="$( mktemp -d )"
    PAYLOAD="${TMP_VS}/payload" 
    SIGNATURE="${TMP_VS}/signature"
    KEY="${TMP_VS}/key"
    OBJECT="${1}"
    KEY_SERVER="${2}"
    KEY_ID="${3}"
    DESTINATION="${4}"
    echo "disable-ipv6" >> "${GNUPGHOME}/dirmngr.conf"

    
    if ! _curl --header "devops-purpose: signature" --output "${SIGNATURE}" "${OBJECT}.asc" ;
    then
        echo_red "Downloading the payload signature failed"
        return 1
    fi
    
    if ! _curl --header "devops-purpose: payload-signed" --output "${PAYLOAD}" "${OBJECT}" ;
    then
        echo_red "Downloading the payload failed"
        return 2
    fi
    #
    # the gpg cli does not natively support retries, forcing us to 
    # manually implement retries to fetch the signature from the 
    # GPG public key server
    #
    if test "${KEY_ID}" = "file" ;
    then
        # pass "file" as the key argument to have this function download the file instead
        if _curl --header "devops-pupose: signature-key" --output "${KEY}" ${KEY_SERVER} ;
        then
            gpg --import "${KEY}" >/dev/null 2>/dev/null
            _returnCode=${?}
            if test ${_returnCode} -ne 0 ;
            then
                echo_red "The PGP key file could not be imported"
            fi
        else
            echo_red "The PGP key file could not be downloaded from ${KEY_SERVER}"
            _returnCode=1
        fi
    else
        _retries=4
        while test ${_retries} -gt 0 ;
        do
            gpg --batch --keyserver ${KEY_SERVER} --recv-keys ${KEY_ID} >/dev/null 2>/dev/null
            _returnCode=${?}
            if test ${_returnCode} -eq 0 ;
            then
                _retries=${_returnCode}
            else
                _retries=$(( _retries - 1 ))
            fi
        done
    fi

    if test ${_returnCode} -ne 0 ;
    then
        echo_red "Obtaining the public key to verify the payload signature failed"
        return ${_returnCode}
    fi
    
    gpg --batch --verify "${SIGNATURE}" "${PAYLOAD}" >/dev/null 2>/dev/null
    _returnCode=${?}
    if test ${_returnCode} -eq 0 ;
    then
        echo_green "The payload signature was successfully verified."
        mv "${PAYLOAD}" "${DESTINATION}"
    else
        echo_red "The payload signature verification failed."
        rm "${PAYLOAD}"
    fi
	gpgconf --kill all  >/dev/null 2>/dev/null
    return ${_returnCode}
}

set -x
apk --no-cache --update add curl jq zip gnupg

BASE="${BASE:-/opt}"
if download_and_verify "https://gte-bits-repo.s3.amazonaws.com/tini" "https://gte-bits-repo.s3.amazonaws.com/signing-key-public.gpg" "file" "${BASE}/tini" ;
then
    echo_green Successfully obtained and verified tini
    chmod +x "${BASE}/tini" 
    rm -f "${PAYLOAD}" "${SIGNATURE}" 
else
    echo_red Could not obtain or verify tini
    exit 1
fi

if download_and_verify "https://gte-bits-repo.s3.amazonaws.com/gosu" "https://gte-bits-repo.s3.amazonaws.com/signing-key-public.gpg" "file" "${BASE}/gosu" ;
then
    echo_green Successfully obtained and verified gosu
    chmod +x "${BASE}/gosu" 
    "${BASE}/gosu" nobody true 
    rm -f ${PAYLOAD} ${SIGNATURE} 
else
    echo_red Could not obtain or verify gosu
    exit 1
fi
exit 0