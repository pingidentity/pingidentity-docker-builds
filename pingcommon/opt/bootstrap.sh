#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x
# shellcheck source=staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"


_userID=$( id -u )
_groupID=$( id -g )
_runUnprivileged=""

addGroup_alpine ()
{
    _groupID="${1}"
    _groupName="${2}"
    addgroup -g "${_groupID}" "${_groupName}"
}

addGroup_centos ()
{
    _groupID="${1}"
    _groupName="${2}"
    groupadd --gid "${_groupID}" "${_groupName}"
}

addGroup_ubuntu ()
{
    _groupID="${1}"
    _groupName="${2}"
    addgroup --gid "${_groupID}" "${_groupName}"
}

addUser_alpine ()
{
    _userID="${1}"
    _userName="${2}"
    _groupName="${3}"
    adduser -u "${_userID}" -G "${_groupName}" -D -H -s /bin/false "${_userName}"
}

addUser_ubuntu ()
{
    _userID="${1}"
    _userName="${2}"
    _groupID="${3}"
    adduser --uid "${_userID}" --gid "${_groupID}" --no-create-home --shell /bin/false --disabled-login --disabled-password --gecos "" "${_userName}"
}

addUser_centos ()
{
    _userID="${1}"
    _userName="${2}"
    _groupName="${3}"
    adduser --uid "${_userID}" --gid "${_groupName}" --no-create-home --shell /bin/false "${_userName}"
}

addUser ()
{
    _userID="${1}"
    _userName="${2}"
    _groupID="${3}"
    _groupName="${4}"
    if  test -n "${_userID}" && test -n "${_userName}" && test -n "${_groupName}"
    then
        isOS alpine && addUser_alpine "${_userID}" "${_userName}" "${_groupName}"
        isOS centos && addUser_centos "${_userID}" "${_userName}" "${_groupName}"
        isOS ubuntu && addUser_ubuntu "${_userID}" "${_userName}" "${_groupID}"
    fi
}

addGroup ()
{
    _groupID="${1}"
    _groupName="${2}"
    if test -n "${_groupID}" && test -n "${_groupName}"
    then
        isOS alpine && addGroup_alpine ${_groupID} ${_groupName}
        isOS centos && addGroup_centos ${_groupID} ${_groupName}
        isOS ubuntu && addGroup_ubuntu ${_groupID} ${_groupName}
    fi
}

fixPermissions ()
{
    touch /etc/motd
    # _candidateList=""

    find "${BASE}" -not -name in -mindepth 1 -maxdepth 1 | while read -r directory
    do
        # _candidateList="${_candidateList:+${_candidateList} }${directory}"
        chown -Rf ${PING_CONTAINER_UID}:${PING_CONTAINER_GID} /etc/motd "${directory}"
        chmod -Rf go-rwx "${directory}"
    done

    # If there is a SECRETS_DIR, chmod to 777 for rwx to non-privileged user
    if test -d "${SECRETS_DIR}"; then
        chmod ugo+rwx "${SECRETS_DIR}"
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


removePackageManager ()
{
    isOS alpine && removePackageManager_alpine
    isOS centos && removePackageManager_centos
    isOS ubuntu && removePackageManager_ubuntu
}


echo "### Bootstrap"
if test "${_userID}" -eq 0
then
    # if the user is root we need to check if and how to step down
    if test "${PING_CONTAINER_PRIVILEGED}" != "true"
    then
        _effectiveGroupName=$( awk 'BEGIN{FS=":"}$3~/^'"${PING_CONTAINER_GID}"'$/{print $1}' /etc/group )
        test -z "${_effectiveGroupName}" && _effectiveGroupName=${PING_CONTAINER_GNAME}

        _effectiveUserName=$( awk 'BEGIN{FS=":"}$3~/^'"${PING_CONTAINER_UID}"'$/{print $1}' /etc/passwd )
        test -z "${_effectiveUserName}" && _effectiveUserName=${PING_CONTAINER_UNAME}

        echo "### Pattern: inside-out"
        echo "### Stepdown requested to :"
        echo "###     user : ${PING_CONTAINER_UNAME} (id:${PING_CONTAINER_UID})"
        echo "###     group: ${PING_CONTAINER_GNAME} (id:${PING_CONTAINER_GID})"
        echo "### Stepdown effective to:"
        echo "###     user : ${_effectiveUserName} (id:${PING_CONTAINER_UID})"
        echo "###     group: ${_effectiveGroupName} (id:${PING_CONTAINER_GID})"

        # if the effective group name is as requested, it means no existing group with that name exist, create it
        if test "${_effectiveGroupName}" = "${PING_CONTAINER_GNAME}"
        then
            # shellcheck disable=SC2086
            addGroup ${PING_CONTAINER_GID} ${_effectiveGroupName}
        fi

        # if the effective user name is as requested, it means no existing user with that name exist, create it
        if test "${_effectiveUserName}" = "${PING_CONTAINER_UNAME}"
        then
            # shellcheck disable=SC2086
            addUser ${PING_CONTAINER_UID} ${_effectiveUserName} ${PING_CONTAINER_GID} ${_effectiveGroupName}
        fi
        # we step down from the root user to the requested user so we strip /opt of world rights
        fixPermissions

        # compute the step-down command that is going to be shimmed before tini
        _runUnprivileged="${BASE}/gosu ${PING_CONTAINER_UID}"

        removePackageManager
    fi
else
    _effectiveGroupName=$( awk 'BEGIN{FS=":"}$3~/^'"${_groupID}"'$/{print $1}' /etc/group )
    test -z "${_effectiveGroupName}" && _effectiveGroupName="undefined group"

    _effectiveUserName=$( awk 'BEGIN{FS=":"}$3~/^'"${_userID}"'$/{print $1}' /etc/passwd )
    test -z "${_effectiveUserName}" && _effectiveUserName="undefined user"

    echo "### Pattern: outside-in"
    echo "###     user : ${_effectiveUserName} (id: ${_userID})"
    echo "###     group: ${_effectiveGroupName} (id: ${_groupID})"
fi

# if the current process id is not 1, tini needs to register as sub-reaper
if test $$ -ne 1
then
    _subReaper="-s"
fi

# shellcheck disable=SC2086,SC2048
exec ${_runUnprivileged} "${BASE}/tini" ${_subReaper} -- "${BASE}/entrypoint.sh" ${*}