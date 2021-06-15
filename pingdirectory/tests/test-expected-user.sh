#!/usr/bin/env sh
_expectedUserID=$1
_expectedGroupID=$2
_file="$( mktemp -d )/result.ldif"
ldapsearch \
    --outputFile "${_file}" \
    --teeResultsToStandardOut \
    --baseDN cn=system\ information,cn=monitor \
    --scope base '(&)'
_returnCode=${?}
if test ${_returnCode} -eq 0
then
    _user=$( awk '$1~/^userName:$/{print $2}' < "${_file}" )
    _userID=$( id -u "${_user}" )
    _groupID=$( id -g "${_user}" )
    if test "${_userID}" -eq "${_expectedUserID}" && test "${_groupID}" -eq "${_expectedGroupID}"
    then
        exit 0
    else
        echo "User ID and/or group ID did not match expected"
        echo "Expected user ID '${_expectedUserID}', got '${_userID}'"
        echo "Expected group ID '${_expectedGroupID}', got '${_groupID}'"
        exit 1
    fi
fi
echo "ldapsearch failure"
exit 1