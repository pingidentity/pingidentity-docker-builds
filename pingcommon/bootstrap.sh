#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x

_userID=$(id -u)
_runUnprivileged=""

addUser_alpine ()
{
    _uid=${1}
    _gid=${2}
    if type apk >/dev/null 2>/dev/null && test -n "${_uid}" && test -n "${_gid}" ; then
        addgroup -g ${_gid} ${PING_CONTAINER_GNAME}
        adduser -u ${_uid} -G ${PING_CONTAINER_GNAME} -D -H -s /bin/false ${PING_CONTAINER_UNAME}
    fi
}

addUser_ubuntu ()
{
    _uid=${1}
    _gid=${2}
    if type apt >/dev/null 2>/dev/null && test -n "${_uid}" && test -n "${_gid}" ; then
        addgroup --gid ${_gid}} ${PING_CONTAINER_GNAME}
        adduser --uid ${_uid} --gid ${PING_CONTAINER_GNAME} --no-create-home --shel /bin/false --disabled-login --disabled-password --gecos "" ${PING_CONTAINER_UNAME}
    fi
}

addUser_centos ()
{
    _uid=${1}
    _gid=${2}
    if type yum >/dev/null 2>/dev/null && test -n "${_uid}" && test -n "${_gid}" ; then
        groupadd --gid ${_gid} ${PING_CONTAINER_GNAME}
        adduser --uid ${_uid} --gid ${PING_CONTAINER_GNAME} --no-create-home --shell /bin/false ${PING_CONTAINER_UNAME}
    fi
}

addUser ()
{
    _uid=${1}
    _gid=${2}
    if  test -n "${_uid}" && test -n "${_gid}" ; then
        addUser_alpine ${_uid} ${_gid}
        addUser_centos ${_uid} ${_gid}
        addUser_ubuntu ${_uid} ${_gid}
    fi
}

fixPermissions ()
{
    chown -Rf ${PING_CONTAINER_UNAME}:${PING_CONTAINER_GNAME} /opt
    chmod -Rf go-rwx /opt
}

echo "### Bootstrap"
if test ${_userID} -eq 0 ; then
    # if the user is root we need to check if and how to step down
    if test "${PING_CONTAINER_PRIVILEGED}" != "true" ; then
        echo "### Stepdown to" 
        echo "###     user : ${PING_CONTAINER_UNAME}(${PING_CONTAINER_UID})"
        echo "###     group: ${PING_CONTAINER_GNAME}(${PING_CONTAINER_GID})"
        addUser ${PING_CONTAINER_UID} ${PING_CONTAINER_GID}
        fixPermissions
        # compute the step-down command
        _runUnprivileged="${BASE}/gosu ${PING_CONTAINER_UNAME}"
    fi
fi

exec ${_runUnprivileged} tini -- ${BASE}/entrypoint.sh ${*}