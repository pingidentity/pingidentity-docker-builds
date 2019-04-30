#!/usr/bin/env sh
${VERBOSE} && set -x

# shellcheck source=../lib.sh
. "${BASE}/lib.sh"

getValue ()
{
    eval printf '%s' "\${${1}}"
}

getProfile ()
{
    serverProfileUrl=$( getValue "${1}_URL" )
    serverProfileBranch=$( getValue "${1}_BRANCH" )
    serverProfilePath=$( getValue "${1}_PATH" )

    # this is a precaution because git clone needs an empty target
    rm -rf "${SERVER_PROFILE_DIR}"
    if test -n "${serverProfileUrl}" ; then
        # deploy configuration if provided
        git clone --depth 1 ${serverProfileBranch:+--branch} ${serverProfileBranch} "${serverProfileUrl}" "${SERVER_PROFILE_DIR}"
        die_on_error 141 "Git clone failure"  || exit ${?}
        # if test -n "${serverProfileBranch}" ; then
        #     # https://github.com/koalaman/shellcheck/wiki/SC2103
        #     (
        #     cd "${SERVER_PROFILE_DIR}" || return
        #     git checkout "${serverProfileBranch}"
        #     die_on_error 14 "Git checkout failure (bad branch name?)"
        #     )
        # fi
        # shellcheck disable=SC2086
        cp -af ${SERVER_PROFILE_DIR}/${serverProfilePath}/* "${STAGING_DIR}"
        die_on_error 142 "Copy to staging failure"  || exit ${?}
    fi    
}

getParent ()
{
    echo ${serverProfilePrefix}${serverProfileName:+_}${serverProfileName}"_PARENT"
}



serverProfilePrefix="SERVER_PROFILE"
serverProfileName=""
serverProfileParent=$( getParent )
serverProfileList=""

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

# if ! test -z "${SERVER_PROFILE_URL}" ; then
#     # deploy configuration if provided
#     git clone "${SERVER_PROFILE_URL}" "${SERVER_PROFILE_DIR}"
#     die_on_error 141 "Git clone failure"  || exit ${?}
#     if ! test -z "${SERVER_PROFILE_BRANCH}" ; then
#         # https://github.com/koalaman/shellcheck/wiki/SC2103
#         (
#         cd "${SERVER_PROFILE_DIR}" || return
#         git checkout "${SERVER_PROFILE_BRANCH}"
#         die_on_error 14 "Git checkout failure (bad branch name?)"
#         )
#     fi
#     # shellcheck disable=SC2086
#     cp -af ${SERVER_PROFILE_DIR}/${SERVER_PROFILE_PATH}/* "${STAGING_DIR}"
#     die_on_error 142 "Copy to staging failure"  || exit ${?}
# fi