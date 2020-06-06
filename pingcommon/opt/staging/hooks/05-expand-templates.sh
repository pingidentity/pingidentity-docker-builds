#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Using the envsubst command, this will look through any files in the
#- STAGING_DIR that end in `.subst` or `.subst.default`
#- and substitute any variables the files with the the value of those
#- variables, if the variable is set.
#-
#- Variables may come from (in order of precedence):
#-  - The '.env' file from the profiles and intra container env variables
#-  - The environment variables or env-file passed to continaer on startup
#-  - The container's os
#-
#- If a .zip file ends with `.zip.subst` (especially useful for pingfederate
#- for example with data.zip) then:
#-  - file will be unzipped
#-  - any files ending in `.subst` will be processed to substiture variables
#-  - zipped back up in to the same file without the `.subst` suffix
#-
#- If a file ends with `.subst.default` (intended to only be expanded as a
#- default if the file is not found) then it will be substituted:
#-  - If the RUN_PLAN==START and the file is not found in staging
#-  - If the RUN_PLAN==RESTART and the file is found in staging or the OUT_DIR
#-
#- >Note: If a string of $name is sould be ignored during a substitution, then
#- A special vabiable ${_DOLLAR_} should be used.  This is not required any longer
#- and deprecated, but available for any older server-profile versions.
#-
#- >Example: ${_DOLLAR_}{username} ==> ${username}
#-
${VERBOSE} && set -x

# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

#
# TODO GDO-310 created to remove the following in the future.  Along with the
#      documenation above
#
# shellcheck disable=SC2034
export _DOLLAR_="$"

#
# getEnvKeys
# Create a list of environment keys
#
getEnvKeys()
{
    env | cut -d'=' -f1 | sed -e 's/^/$/'
}

#
# expand files in current directory
# we check if there are templates that we have to run through env subst
#
expandFiles()
{
    #
    # First, let's process all files that end in .subst
    #
    echo "  Processing templates"
    # shellcheck disable=SC2044
    for template in $( find "." -type f -iname \*.subst )
    do
        echo "    t - ${template}"
        envsubst "'$(getEnvKeys)'" < "${template}" > "${template%.subst}"
        rm -f "${template}"
    done

    #
    # Second, let's process all files that end in .subst.default
    # These are to processed only if they aren't found in the current
    # set of files or if it's a RESTART and found in the OUT_DIR
    #
    echo "  Processing defaults"
    # shellcheck disable=SC2044
    for template in $( find "." -type f -iname \*.subst.default )
    do
        printf "    d - %s .. " "${template}"
        _effectiveFile="${template%.subst.default}"
        _processDefault="true"
        if test "${RUN_PLAN}" = "RESTART"
        then
            _targetInstanceFile="${OUT_DIR}${_effectiveFile#.}"
            if test -f "${_targetInstanceFile}" || test -f "${_effectiveFile}"
            then
                _processDefault="false"
            fi
        else
            if test -f "${_effectiveFile}"
            then
                _processDefault="false"
            fi
        fi
        if test "${_processDefault}" = "true"
        then
            envsubst "'$(getEnvKeys)'" < "${template}" > "${_effectiveFile}"
            echo_green "expanded"
        else
            echo_yellow "skipped"
        fi
        rm -f "${template}"
    done
}

# main
cd "${STAGING_DIR}" || exit 15
# shellcheck disable=SC2044
for _zipBundle in $( find "." -type f -iname \*.zip.subst )
do
    echo "expanding .zip file - ${_zipBundle}"

    # create a temporary zip directory and unzip the .zip.subst artifacts there
    _zipBase="/tmp/zip"
    mkdir -p ${_zipBase} || exit 151
    unzip -qd "${_zipBase}" "${STAGING_DIR}/${_zipBundle}" || exit 152

    # change directory to the expanded .zip and expand all files
    cd "${_zipBase}" || exit 153

    expandFiles

    # zip up the newly expanded files into a new zip
    zip -qr "${STAGING_DIR}/${_zipBundle%.subst}" * || exit 154

    # cleanup temporary zip directory and old .subst file
    rm -rf "${_zipBase}"
    rm -f "${STAGING_DIR}/${_zipBundle}"
done

echo "expanding files..."
cd "${STAGING_DIR}" || exit 15

expandFiles

#
# If a directory called _data.zip_ and there isn't a data.zip already present, then
# build up the data.zip with the _data.zip_ contents.  This supports the use case
# where data.zip artifacts from a PingFederate export can be stored as artifacts
#
# TODO GDO-311 created to remove the following in the future.
#
cd "${STAGING_DIR}" || exit 15

# shellcheck disable=SC2044
for _zipBundle in $( find "." -type d -iname _data.zip_ )
do
    echo "Ziping up ${_zipBundle} in to a data.zip..."

    cd "${_zipBundle}" || exit 15

    if test ! -d ../data.zip
    then
        zip -qr "../data.zip" * || exit 18
    else
        echo_yellow "  Possible error.  Also found a data.zip file. Will use data.zip file."
    fi

    cd "${STAGING_DIR}" || exit 15
done
