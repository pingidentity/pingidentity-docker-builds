#!/usr/bin/env sh
_file="$( mktemp -d)/result.ldif"
ldapsearch \
    --outputFile ${_file} \
    --teeResultsToStandardOut \
    --baseDN cn=system\ information,cn=monitor \
    --scope base '(&)'
_returnCode=${?}
if test ${_returnCode} -eq 0 ;
then
    _user=$( awk '$1~/^userName:$/{print $2}' < ${_file} )
    _userID=$( id -u ${_user} )
    _groupID=$( id -g ${_user} )
    if test "${_user}" = "ping" && test ${_userID} -eq 1234 && test ${_groupID} -eq 9876 ;
    then
        exit 0
    fi
fi
exit 1