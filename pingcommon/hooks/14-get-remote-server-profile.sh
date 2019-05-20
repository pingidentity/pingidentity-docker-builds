#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=../lib.sh
. "${BASE}/lib.sh"

getValue ()
{
    eval printf '%s' "\${${1}}"
}

# performs a git clone on the server profile passed
getProfile ()
{
    serverProfileUrl=$( getValue "${1}_URL" )
    serverProfileBranch=$( getValue "${1}_BRANCH" )
    serverProfilePath=$( getValue "${1}_PATH" )

    # this is a precaution because git clone needs an empty target
    rm -rf "${SERVER_PROFILE_DIR}"
    if test -n "${serverProfileUrl}" ; then
        # deploy configuration if provided
        echo "Getting ${1}"
        echo "  git url: ${serverProfileUrl}"
        test -n "${serverProfileBranch}" && echo "   branch: ${serverProfileBranch}"
        test -n "${serverProfilePath}" && echo "     path: ${serverProfilePath}"

        git clone --depth 1 ${serverProfileBranch:+--branch} ${serverProfileBranch} "${serverProfileUrl}" "${SERVER_PROFILE_DIR}"
        die_on_error 141 "Git clone failure"  || exit ${?}
        
        # shellcheck disable=SC2086
        cp -af ${SERVER_PROFILE_DIR}/${serverProfilePath}/* "${STAGING_DIR}"
        die_on_error 142 "Copy to staging failure"  || exit ${?}
    fi    
}

# takes the current server profile name and appends _PARENT to the end
#   Example: SERVER_PROFILE          returns SERVER_PROFILE_PARENT
#            SERVER_PROFILE_LICENSE  returns SERVER_PROFILE_LICENSE_PARENT
getParent ()
{
    echo ${serverProfilePrefix}${serverProfileName:+_}${serverProfileName}"_PARENT"
}

########################################################################################
# main
serverProfilePrefix="SERVER_PROFILE"
serverProfileName=""
serverProfileParent=$( getParent )
serverProfileList=""

# creates a spaced separated list of server profiles starting with the parent most
# profile and moving down.
while test -n "$( getValue ${serverProfileParent} )" ; do
    # echo "Profile parent variable: ${serverProfileParent}"
    serverProfileName=$( getValue ${serverProfileParent} )
    serverProfileList="${serverProfileName}${serverProfileList:+ }${serverProfileList}"
    # echo "Profile parent value   : ${serverProfileName}"
    serverProfileParent=$( getParent )
done

for serverProfileName in ${serverProfileList} ; do
    getProfile "${serverProfilePrefix}_${serverProfileName}"
done
getProfile ${serverProfilePrefix}
