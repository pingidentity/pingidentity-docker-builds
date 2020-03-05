#!/usr/bin/env sh
test -f "/opt/build.sh.pre" && sh /opt/build.sh.pre

echo "Build stage (shim-specific installations)"
set -eux
_osID=$( awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' </etc/os-release 2>/dev/null )

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
    echo "disable-ipv6" >> "${GNUPGHOME}/dirmngr.conf"
    set -e
    curl -sSLo "${PAYLOAD}" "${OBJECT}"
    curl -sSLo "${SIGNATURE}" "${OBJECT}.asc"
    gpg --batch --keyserver ${KEY_SERVER} --recv-keys ${KEY_ID}
    gpg --batch --verify "${SIGNATURE}" "${PAYLOAD}"
    set +e
    mv "${PAYLOAD}" "${DESTINATION}"
	gpgconf --kill all 
}

case "${_osID}" in
    alpine)
        apk --no-cache --update add git git-lfs curl ca-certificates jq zip gnupg libintl openssh-client
        # install package dependency for variable substitution
        apk --no-cache --update add --virtual build_deps gettext
        # extract just the binary we need
        cp /usr/bin/envsubst /usr/local/bin/envsubst 
        # wipe the dependency
        apk del build_deps
        # altogether remove the package manager
        rm -rf /sbin/apk /etc/apk /lib/apk /usr/share/apk /var/lib/apk
    ;;
    centos)
        rm -rf /var/lib/rpm
        rpmdb -v --rebuilddb
        _versionID=$( awk '$0~/^VERSION_ID=/{split($1,version,"=");gsub(/"/,"",version[2]);print version[2];}' /etc/os-release )
        yum -y update --releasever ${_versionID}
        yum -y install --releasever ${_versionID} epel-release
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
        # yum -y install java-11-openjdk-devel gettext bind-utils git git-lfs jq unzip openssh-clients gnupg nmap-ncat
        yum -y install  --releasever ${_versionID} gettext bind-utils git git-lfs jq unzip openssh-clients gnupg nmap-ncat
        yum -y clean all
        rm -rf /var/cache/yum
    ;;
    ubuntu)
        apt-get -y update
        apt-get -y install apt-utils
        apt-get -y install curl gettext-base dnsutils git git-lfs jq unzip openssh-client gnupg netcat
        apt-get -y autoremove
        rm -rf /var/lib/apt/lists/*
    ;;
esac

BASE="${BASE:-/opt}"
# download_and_verify "https://github.com/krallin/tini/releases/download/v0.18.0/tini-static" ha.pool.sks-keyservers.net 6380DC428747F6C393FEACA59A84159D7001A4E5 "${BASE}/tini"
download_and_verify "https://github.com/krallin/tini/releases/download/v0.18.0/tini-static" hkp://p80.pool.sks-keyservers.net:80 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 "${BASE}/tini"
chmod +x "${BASE}/tini" 
rm -f "${PAYLOAD}" "${SIGNATURE}" 

download_and_verify "https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64" hkps://keys.openpgp.org B42F6819007F00F88E364FD4036A9C25BF357DD4 "${BASE}/gosu"
chmod +x "${BASE}/gosu" 
"${BASE}/gosu" nobody true 
rm -f ${PAYLOAD} ${SIGNATURE} 
rm -r "$GNUPGHOME" "${TMP_VS}" 

chmod -Rf a+rwx /opt 

test -f "/opt/build.sh.post" && sh /opt/build.sh.post

# delete self
rm -f "${0}"