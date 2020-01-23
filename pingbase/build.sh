#!/usr/bin/env sh
set -eux
if type apt-get >/dev/null 2>/dev/null ; then
    apt-get -y update
    apt-get -y  upgrade
    apt-get -y install apt-utils
    apt-get -y install openjdk-11-jdk curl gettext-base dnsutils git git-lfs jq unzip openssh-client gnupg netcat
    apt-get -y autoremove
    rm -rf /var/lib/apt/lists/*
fi

if type yum >/dev/null 2>/dev/null ; then
    yum update -y
    yum upgrade -y
    yum -y install epel-release
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
    yum -y install java-11-openjdk-devel gettext bind-utils git git-lfs jq unzip openssh-clients gnupg nmap-ncat
    yum -y autoremove 
    yum -y clean all
    rm -rf /var/cache/yum
fi

if type apk >/dev/null 2>/dev/null ; then
    apk --no-cache --update add git git-lfs curl ca-certificates jq zip gnupg libintl openssh-client openjdk8
    apk add --virtual build_deps gettext 
    cp /usr/bin/envsubst /usr/local/bin/envsubst 
    apk del build_deps
fi

download_and_verify ()
{
	export GNUPGHOME="$(mktemp -d)" 
    TMP_VS="$( mktemp -d )"
    PAYLOAD="${TMP_VS}/payload" 
    SIGNATURE="${TMP_VS}/signature" 
    OBJECT="${1}"
    KEY_SERVER="${2}"
    KEY_ID="${3}"
    DESTINATION="${4}"
    set -e
    curl -sSLo "${PAYLOAD}" "${OBJECT}" 
    curl -sSLo "${SIGNATURE}" "${OBJECT}.asc" 
    gpg --batch --keyserver ${KEY_SERVER} --recv-keys ${KEY_ID} 
    gpg --batch --verify "${SIGNATURE}" "${PAYLOAD}" 
    set +e
    mv "${PAYLOAD}" "${DESTINATION}"
	gpgconf --kill all 
}
BASE="${BASE:-/opt}"
download_and_verify "https://github.com/krallin/tini/releases/download/v0.18.0/tini-static" ha.pool.sks-keyservers.net 6380DC428747F6C393FEACA59A84159D7001A4E5 "${BASE}/tini"
chmod +x "${BASE}/tini" 
rm -f "${PAYLOAD}" "${SIGNATURE}" 

download_and_verify "https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64" hkps://keys.openpgp.org B42F6819007F00F88E364FD4036A9C25BF357DD4 "${BASE}/gosu"
chmod +x "${BASE}/gosu" 
"${BASE}/gosu" nobody true 
rm -f ${PAYLOAD} ${SIGNATURE} 
rm -r "$GNUPGHOME" "${TMP_VS}" 

chmod -Rf a+rwx /opt 

rm -f "${0}"