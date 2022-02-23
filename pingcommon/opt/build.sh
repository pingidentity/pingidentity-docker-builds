#!/usr/bin/env sh
test -f "/opt/build.sh.pre" && sh /opt/build.sh.pre

# Update file permissions for the BASE for the default container user,
# and update the /var/lib/nginx owner if necessary.
fixPermissions() {
    test -f /etc/motd || touch /etc/motd
    chmod go+w /etc/motd

    chown -Rf 9031:0 /etc/motd

    # Environment variables for BASE isn't available here.
    BASE=/opt

    #fix permissions to ping user and root group. Removes permissions from others
    chown -Rf 9031:0 "${BASE}"
    chmod -Rf o-rwx "${BASE}"

    # make shell scripts executable for the user
    # this is safe to do "blind" as it only affects files with the .sh extension
    # for the user defined in the image
    find "${BASE}" -type f -iname \*.sh -exec chmod u+x '{}' \+

    #fix group permissions from owner
    chmod -Rf g=u "${BASE}"

    if grep ^nginx: /etc/passwd > /dev/null; then
        # rebase ownerships for nginx to ping user and root group
        find / -xdev -not -path "/sys/*" -not -path "/proc/*" -not -path "/dev/*" -user nginx -exec chown 9031 {} +
        find / -xdev -not -path "/sys/*" -not -path "/proc/*" -not -path "/dev/*" -group nginx -exec chgrp 0 {} +
    fi
}

removePackageManager_alpine() {
    rm -f /sbin/apk
}

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
    centos | rhel)
        _versionID=$(awk '$0~/^VERSION_ID=/{split($1,version,"=");gsub(/"/,"",version[2]);print version[2];}' /etc/os-release)
        _packages="bind-utils cronie gettext git git-lfs jq net-tools nmap-ncat openssh-clients procps-ng unzip zip"

        if test "${_osID}" = "centos"; then
            rm -rf /var/lib/rpm
            rpmdb -v --rebuilddb
            rm -fr /var/cache/yum/*
            yum clean all
            yum -y update --releasever "${_versionID}"
            yum -y install --releasever "${_versionID}" epel-release
            curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
        fi
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
    ubuntu)
        apt-get -y update
        apt-get -y install apt-utils
        apt-get -y install curl gettext-base dnsutils git git-lfs jq unzip openssh-client netcat
        apt-get -y autoremove
        rm -rf /var/lib/apt/lists/*

        # Create user in root group
        adduser --uid 9031 --ingroup root --disabled-password --shell /bin/false ping

        removePackageManager_ubuntu
        ;;
esac

# create stubs for volume mounts
for dir in "backup" "in" "logs" "out"; do
    mkdir "/opt/${dir}"
done

# Do we need this ?
# chmod -Rf a+rwx /opt

test -f "/opt/build.sh.post" && sh /opt/build.sh.post

# generate the staging manifest
find "/opt/staging" > "/opt/staging-manifest.txt"

fixPermissions

# delete self
rm -f "${0}"
set +x
echo "Build done."

exit 0
