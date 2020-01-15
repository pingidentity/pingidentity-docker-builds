#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x

_userID=$(id -u)
_runUnprivileged=""

addUser_alpine ()
{
    if which apk >/dev/null ; then
        addgroup -g ${2} identity
        adduser -u ${1} -G identity -D -H -s /bin/false ping
    fi
}

addUser_ubuntu ()
{
    if which apt >/dev/null ; then
        addgroup --gid ${2} identity
        adduser --uid ${1} --gid identity --no-create-home --shel /bin/false --disabled-login --disabled-password --gecos "" ping
    fi
}

addUser_centos ()
{
    if which yum 2>/dev/null ; then
        groupadd --gid ${2} identity
        adduser --uid ${1} --gid identity --no-create-home --shell /bin/false ping
    fi
}

addUser ()
{
    _uid=${1}
    _gid=${2}
    addUser_alpine ${_uid} ${_gid}
    addUser_centos ${_uid} ${_gid}
    addUser_ubuntu ${_uid} ${_gid}
}

fixPermissions ()
{
    chown -Rf ${PING_CONTAINER_UNAME}:${PING_CONTAINER_GNAME} /opt
    # chmod -Rf 700 /opt    
}

if test ${_userID} -eq 0 ; then
    # if the user is root we need to check if and how to step down
    if test "${PING_CONTAINER_PRIVILEGED}" != "true" ; then
        addUser ${PING_CONTAINER_UID} ${PING_CONTAINER_GID}
        fixPermissions
        # compute the step-down command
        _runUnprivileged="${BASE}/gosu ${PING_CONTAINER_UNAME}"
    fi
fi

exec ${_runUnprivileged} ./entrypoint.sh $*