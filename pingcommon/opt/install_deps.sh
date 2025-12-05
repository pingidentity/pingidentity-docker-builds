#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

echo "Build stage (shim-specific installations)"
set -x
_osID=$(awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' < /etc/os-release 2> /dev/null)

case "${_osID}" in
    alpine)
        apk --no-cache --update add git git-lfs curl ca-certificates zip libintl openssh-client gettext

        # install jq and dependency library
        apk --no-cache add oniguruma jq

        apk --no-cache --update add fontconfig ttf-dejavu

        #Upgrade all packages
        apk -U upgrade

        # Removing apk installed file, removing false positive CVEs
        rm /lib/apk/db/installed

        # Create user in root group
        adduser --uid 9031 --ingroup root --disabled-password --shell /bin/false ping
        ;;
    centos)
        _versionID=$(awk '$0~/^VERSION_ID=/{split($1,version,"=");gsub(/"/,"",version[2]);print version[2];}' /etc/os-release)
        _packages="bind-utils cronie gettext git git-lfs jq net-tools nmap-ncat openssh-clients procps-ng unzip zip"

        rm -rf /var/lib/rpm
        rpmdb -v --rebuilddb
        rm -fr /var/cache/yum/*
        yum clean all
        yum -y update --releasever "${_versionID}"
        yum -y install --releasever "${_versionID}" epel-release
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
        yum -y update --releasever "${_versionID}"
        # Word-splitting expected in listing yum packages to install
        # shellcheck disable=SC2086
        yum -y install --releasever "${_versionID}" ${_packages}
        yum -y clean all
        rm -fr /var/cache/yum/* /tmp/yum_save*.yumtx /root/.pki

        # Create user in root group
        useradd --uid 9031 --gid root --shell /bin/false ping
        ;;
    rhel)
        _versionID=$(awk '$0~/^VERSION_ID=/{split($1,version,"=");gsub(/"/,"",version[2]);print version[2];}' /etc/os-release)
        _packages="bind-utils cronie gettext git git-lfs jq net-tools nmap-ncat openssh-clients procps-ng tar unzip zip findutils"

        microdnf -y update --releasever "${_versionID}"
        # Word-splitting expected in listing microdnf packages to install
        # shellcheck disable=SC2086
        microdnf -y install --releasever "${_versionID}" ${_packages}
        microdnf -y clean all
        rm -fr /var/cache/yum/* /var/lib/dnf/history.*

        # Create user in root group
        useradd --uid 9031 --gid root --shell /bin/false ping
        ;;
    ubuntu)
        apt-get -y upgrade
        apt-get -y install apt-utils
        apt-get -y install curl gettext-base dnsutils git git-lfs jq unzip openssh-client netcat
        apt-get -y autoremove
        rm -rf /var/lib/apt/lists/*

        # Create user in root group
        adduser --uid 9031 --ingroup root --disabled-password --shell /bin/false ping
        ;;
esac

# Environment variables for BASE isn't available here.
BASE=/opt

#fix permissions to ping user and root group. Removes permissions from others
chown -f 9031:0 "${BASE}"
chmod -f o-rwx "${BASE}"

#fix group permissions from owner
chmod -f g=u "${BASE}"
