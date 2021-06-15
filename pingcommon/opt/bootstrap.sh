#!/usr/bin/env sh
test "${VERBOSE}" = "true" && set -x
# shellcheck source=./staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"


_userID=$( id -u )
_groupID=$( id -g )

echo "### Bootstrap"
if test "${_userID}" -eq 0
then
    echo_yellow "### Warning: running container as root user"
else
    echo "### Using the default container user and group"

    _effectiveGroupName=$( awk 'BEGIN{FS=":"}$3~/^'"${_groupID}"'$/{print $1}' /etc/group )
    test -z "${_effectiveGroupName}" && _effectiveGroupName="undefined group"

    _effectiveUserName=$( awk 'BEGIN{FS=":"}$3~/^'"${_userID}"'$/{print $1}' /etc/passwd )
    test -z "${_effectiveUserName}" && _effectiveUserName="undefined user"

    echo "### Container user and group"
    echo "###     user : ${_effectiveUserName} (id: ${_userID})"
    echo "###     group: ${_effectiveGroupName} (id: ${_groupID})"
fi

# if the current process id is not 1, tini needs to register as sub-reaper
if test $$ -ne 1
then
    _subReaper="-s"
fi

# shellcheck disable=SC2086,SC2048
exec "${BASE}/tini" ${_subReaper} -- "${BASE}/entrypoint.sh" ${*}