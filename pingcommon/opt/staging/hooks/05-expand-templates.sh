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
#-  - The environment variables or env-file passed to container on startup
#-  - The container's os
#-
#- If a .zip file ends with `.zip.subst` (especially useful for pingfederate
#- for example with data.zip) then:
#-  - file will be unzipped
#-  - any files ending in `.subst` will be processed to substitute variables
#-  - zipped back up in to the same file without the `.subst` suffix
#-
#- If a file ends with `.subst.default` (intended to only be expanded as a
#- default if the file is not found) then it will be substituted:
#-  - If the RUN_PLAN==START and the file is not found in staging
#-  - If the RUN_PLAN==RESTART and the file is found in staging or the OUT_DIR
#-
#- >Note: If a string of $name should be ignored during a substitution, then
#- A special variable ${_DOLLAR_} should be used.  This is not required any longer
#- and deprecated, but available for any older server-profile versions.
#-
#- >Example: ${_DOLLAR_}{username} ==> ${username}
#-
test "${VERBOSE}" = "true" && set -x

# shellcheck source=./pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# TODO GDO-310 created to remove the following in the future.  Along with the documentation above
export _DOLLAR_="$"

#
# getEnvKeys
# Create a list of environment keys
#
getEnvKeys() {
    env | cut -d'=' -f1 | sed -e 's/^/$/'
}

#
# expand files in current directory
# we check if there are templates that we have to run through env subst
#
expandFiles() {
    #
    # First, let's process all files that end in .subst
    #
    echo "  Processing templates"

    find "." -type f -iname \*.subst > tmp
    while IFS= read -r template; do
        echo "    t - ${template}"
        envsubst "'$(getEnvKeys)'" < "${template}" > "${template%.subst}"
        rm -f "${template}"
    done < tmp
    rm tmp

    #
    # Second, let's process all files that end in .subst.default
    # These are to processed only if they aren't found in the current
    # set of files or if it's a RESTART and found in the OUT_DIR
    #
    echo "  Processing defaults"
    find "." -type f -iname \*.subst.default > tmp
    while IFS= read -r template; do
        printf "    d - %s .. " "${template}"
        _effectiveFile="${template%.subst.default}"
        _processDefault="true"
        if test "${RUN_PLAN}" = "RESTART"; then
            _targetInstanceFile="${OUT_DIR}${_effectiveFile#.}"
            if test -f "${_targetInstanceFile}" || test -f "${_effectiveFile}"; then
                _processDefault="false"
            fi
        else
            if test -f "${_effectiveFile}"; then
                _processDefault="false"
            fi
        fi
        if test "${_processDefault}" = "true"; then
            envsubst "'$(getEnvKeys)'" < "${template}" > "${_effectiveFile}"
            echo_green "expanded"
        else
            echo_yellow "skipped"
        fi
        rm -f "${template}"
    done < tmp
    rm tmp
}

# main
cd "${STAGING_DIR}" || exit 15

find "." -type f -iname \*.zip.subst > tmp
while IFS= read -r _zipBundle; do
    echo "expanding .zip file - ${_zipBundle}"

    # create a temporary zip directory and unzip the .zip.subst artifacts there
    _zipBase="/tmp/zip"
    mkdir -p ${_zipBase} || exit 151
    unzip -qd "${_zipBase}" "${STAGING_DIR}/${_zipBundle}" || exit 152

    # change directory to the expanded .zip and expand all files
    cd "${_zipBase}" || exit 153

    expandFiles

    # zip up the newly expanded files into a new zip
    zip -qr "${STAGING_DIR}/${_zipBundle%.subst}" ./* || exit 154

    # cleanup temporary zip directory and old .subst file
    rm -rf "${_zipBase}"
    rm -f "${STAGING_DIR}/${_zipBundle}"
done < tmp
rm tmp

echo "expanding files..."
cd "${STAGING_DIR}" || exit 15

expandFiles

#
# Building a data.zip from a _data.zip_ directory in the server profile
# is no longer supported. See GDO-311.
#
cd "${STAGING_DIR}" || exit 15

if test -d _data.zip_; then
    echo_red "WARNING: Building of data.zip from a _data.zip_ directory is no longer supported."
fi
