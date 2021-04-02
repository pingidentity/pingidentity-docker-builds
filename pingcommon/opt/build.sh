#!/usr/bin/env sh

set -e

test -f "/opt/build.sh.pre" && sh /opt/build.sh.pre

# Update file permissions for the BASE for the default container user,
# and update the /var/lib/nginx owner if necessary.
fixPermissions ()
{
    touch /etc/motd
    # Environment variables for BASE isn't available here.
    BASE=/opt

    find "${BASE}" -mindepth 1 -maxdepth 1 -not -name in| while read -r directory
    do
        chown -Rf 9031:9999 /etc/motd "${directory}"
        chmod -Rf go-rwx "${directory}"
    done

    if test -d /var/lib/nginx; then
        chown -R "ping:identity" /var/lib/nginx
    fi
}

removePackageManager_alpine ()
{
    rm -f /sbin/apk
}

removePackageManager_centos ()
{
    rpm --erase yum
    rpm --erase --nodeps rpm
}

removePackageManager_ubuntu ()
{
    dpkg -P apt
    dpkg -P --force-remove-essential --force-depends dpkg
}


echo "Build stage (shim-specific installations)"
set -x
_osID=$( awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' </etc/os-release 2>/dev/null )

case "${_osID}" in
    alpine)
        apk --no-cache --update add git git-lfs curl ca-certificates zip libintl openssh-client inotify-tools
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

        # Support for the inside-out security pattern, allowing for running as non-privileged user
        apk --no-cache add su-exec

        # Removing apk installed file, removing false positive CVEs
        rm /lib/apk/db/installed

        # rm -rf /sbin/apk /etc/apk /lib/apk /usr/share/apk /var/lib/apk

        apk --no-cache --update add fontconfig ttf-dejavu

        # Create user and group
        addgroup --gid 9999 identity
        adduser --uid 9031 --ingroup identity --disabled-password --shell /bin/false ping

        # Update permissions under /opt
        fixPermissions

        removePackageManager_alpine
    ;;
    centos)
        rm -rf /var/lib/rpm
        rpmdb -v --rebuilddb
        _versionID=$( awk '$0~/^VERSION_ID=/{split($1,version,"=");gsub(/"/,"",version[2]);print version[2];}' /etc/os-release )
        yum -y update --releasever ${_versionID}
        yum -y install --releasever ${_versionID} epel-release
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
        # yum -y install java-11-openjdk-devel gettext bind-utils git git-lfs jq unzip openssh-clients nmap-ncat
        yum -y install --releasever ${_versionID} gettext bind-utils git git-lfs jq unzip openssh-clients nmap-ncat inotify-tools
        yum -y install gcc make
        cd /tmp
        curl -sL https://github.com/ncopa/su-exec/archive/v0.2.tar.gz | tar xzf -
        make -C su-exec-0.2
        cp /tmp/su-exec-0.2/su-exec /usr/local/bin
        yum -y autoremove gcc make
        yum -y clean all
        # rm -rf /var/cache/yum
        rm -fr /var/cache/yum/* /tmp/yum_save*.yumtx /root/.pki

        # Create user and group
        groupadd --gid 9999 identity
        useradd --uid 9031 --gid identity --shell /bin/false ping

        # Update permissions under /opt
        fixPermissions

        #TODO this causes issues because yum is a dependency of other yum-related packages.
        #removePackageManager_centos
    ;;
    ubuntu)
        apt-get -y update
        apt-get -y install apt-utils
        apt-get -y install curl gettext-base dnsutils git git-lfs jq unzip openssh-client netcat inotify-tools
        apt-get -y install gcc make
        cd /tmp
        curl -sL https://github.com/ncopa/su-exec/archive/v0.2.tar.gz | tar xzf -
        make -C su-exec-0.2
        cp /tmp/su-exec-0.2/su-exec /usr/local/bin
        apt-get --purge remove gcc make
        apt-get -y autoremove
        rm -rf /var/lib/apt/lists/*

        # Create user and group
        addgroup --gid 9999 identity
        adduser --uid 9031 --ingroup identity --disabled-password --shell /bin/false ping

        # Update permissions under /opt
        fixPermissions

        removePackageManager_ubuntu
    ;;
esac

chmod -Rf a+rwx /opt

test -f "/opt/build.sh.post" && sh /opt/build.sh.post

find "/opt/staging" > "/opt/staging-manifest.txt"

# delete self
rm -f "${0}"
set +x
echo "Build done."