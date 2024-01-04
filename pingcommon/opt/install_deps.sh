#!/usr/bin/env sh

removePackageManager_alpine() {
    rm -f /sbin/apk
}

# This function causes issues because yum is a dependency of other yum-related packages.
# Currently not used. Disable shellcheck.
# shellcheck disable=SC2317
removePackageManager_centos() {
    rpm --erase yum
    rpm --erase --nodeps rpm
}

removePackageManager_ubuntu() {
    dpkg -P apt
    dpkg -P --force-remove-essential --force-depends dpkg
}

echo "Build stage (shim-specific installations)"
set -x
_osID=$(awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' < /etc/os-release 2> /dev/null)

case "${_osID}" in
    alpine)
        apk --no-cache --update add git git-lfs curl ca-certificates zip libintl openssh-client
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

        apk --no-cache --update add fontconfig ttf-dejavu

        #Upgrade all packages
        apk -U upgrade

        # Removing apk installed file, removing false positive CVEs
        rm /lib/apk/db/installed

        # Create user in root group
        adduser --uid 9031 --ingroup root --disabled-password --shell /bin/false ping

        # altogether remove the package manager
        removePackageManager_alpine
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

        #TODO this causes issues because yum is a dependency of other yum-related packages.
        #removePackageManager_centos
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

        removePackageManager_ubuntu
        ;;
esac

# Environment variables for BASE isn't available here.
BASE=/opt

#fix permissions to ping user and root group. Removes permissions from others
chown -f 9031:0 "${BASE}"
chmod -f o-rwx "${BASE}"

#fix group permissions from owner
chmod -f g=u "${BASE}"
