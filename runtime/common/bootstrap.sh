#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

test "${VERBOSE}" = "true" && set -x
# shellcheck source=./staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

_userID=$(id -u)
_groupID=$(id -g)

echo "### Bootstrap"
if test "${_userID}" -eq 0; then
    echo_yellow "### Warning: running container as root user"
else
    echo "### Using the default container user and group"

    _effectiveGroupName=$(awk 'BEGIN{FS=":"}$3~/^'"${_groupID}"'$/{print $1}' /etc/group)
    test -z "${_effectiveGroupName}" && _effectiveGroupName="undefined group"

    _effectiveUserName=$(awk 'BEGIN{FS=":"}$3~/^'"${_userID}"'$/{print $1}' /etc/passwd)
    test -z "${_effectiveUserName}" && _effectiveUserName="undefined user"

    echo "### Container user and group"
    echo "###     user : ${_effectiveUserName} (id: ${_userID})"
    echo "###     group: ${_effectiveGroupName} (id: ${_groupID})"
fi

# exec straight into the entrypoint: the base image's /sbin/tini runs as pid 1
# and covers reaping (the -s sub-reaper flag existed for the v1 foundation,
# which had no pid-1 tini; the /opt/tini binary came from the retired
# pingcommon carrier image and no longer exists).
# shellcheck disable=SC2086,SC2048
exec "${BASE}/entrypoint.sh" ${*}
