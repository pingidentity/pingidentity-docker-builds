#!/usr/bin/env sh

set -e

test -f "/opt/build.sh.pre" && sh /opt/build.sh.pre

echo "Build stage (shim-specific installations)"
set -x
_osID=$( awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' </etc/os-release 2>/dev/null )

case "${_osID}" in
    alpine)
        apk --no-cache --update add git git-lfs curl ca-certificates zip gnupg libintl openssh-client inotify-tools parallel
        # install package dependency for variable substitution
        apk --no-cache --update add gettext
        # extract just the binary we need
        cp /usr/bin/envsubst /usr/local/bin/envsubst
        # wipe the dependency
        apk --no-cache --update del gettext

        # install jq and dependency library
        apk --no-cache add oniguruma jq
        # extract just the binary we need
        cp /usr/bin/jq /usr/local/bin/jq
        # wipe the jq from the apk installed list
        apk --no-cache del jq
        # altogether remove the package manager

        # Suppor for the inside-out security pattern, allowing for running as non-privilaged user
        apk --no-cache add su-exec

        # Removing apk installed file, removing false positive CVEs
        rm /lib/apk/db/installed

        # rm -rf /sbin/apk /etc/apk /lib/apk /usr/share/apk /var/lib/apk
    ;;
    centos)
        rm -rf /var/lib/rpm
        rpmdb -v --rebuilddb
        _versionID=$( awk '$0~/^VERSION_ID=/{split($1,version,"=");gsub(/"/,"",version[2]);print version[2];}' /etc/os-release )
        yum -y update --releasever ${_versionID}
        yum -y install --releasever ${_versionID} epel-release
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
        # yum -y install java-11-openjdk-devel gettext bind-utils git git-lfs jq unzip openssh-clients gnupg nmap-ncat
        yum -y install  --releasever ${_versionID} gettext bind-utils git git-lfs jq unzip openssh-clients gnupg nmap-ncat inotify-tools
        yum -y clean all
        rm -rf /var/cache/yum
    ;;
    ubuntu)
        apt-get -y update
        apt-get -y install apt-utils
        apt-get -y install curl gettext-base dnsutils git git-lfs jq unzip openssh-client gnupg netcat inotify-tools
        apt-get -y autoremove
        rm -rf /var/lib/apt/lists/*
    ;;
esac

chmod -Rf a+rwx /opt

test -f "/opt/build.sh.post" && sh /opt/build.sh.post

# delete self
rm -f "${0}"
set +x
echo "Build done."