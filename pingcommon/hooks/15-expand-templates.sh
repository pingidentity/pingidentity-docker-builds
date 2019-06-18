#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- Using the envsubst command, this will look through any files that end in 
#- `subst` and substitute any variables the files with the the value of those
#- variables.
#-
#- Variables may come from (in order of precedence):
#-  - The 'env_vars' file from the profiles
#-  - The environment variables or env-file passed to continaer on startup
#-  - The container's os
#-
${VERBOSE} && set -x

# shellcheck source=../lib.sh disable=SC2153
. "${BASE}/lib.sh"

# shellcheck source=/dev/null
if test -f "${STAGING_DIR}/env_vars" ; then
    set -o allexport
    . "${STAGING_DIR}/env_vars"
    set +o allexport
fi

#- >Note: If a string of $name is sould be ignored during a substitution, then 
#- A special vabiable ${_DOLLAR_} should be used.
#-
#- >Example: ${_DOLLAR_}{username} ==> ${username}
#-  
# shellcheck disable=SC2034
export _DOLLAR_="$"

#- If a .zip file ends with `.zip.subst` then:
#- - file will be unzipped 
#- - any files ending in `.subst` will be processed to substiture variables
#- - zipped back up in to the same file without the `.subst` suffix
#- This is especially useful for pingfederate for example with data.zip
#-

#
# expand files in current directory
# we check if there are templates that we have to run through env subst
#
expandFiles()
{
    # shellcheck disable=SC2044
    for template in $( find "." -type f -iname \*.subst ) ; do
        echo "  - ${template}"
        envsubst < "${template}" > "${template%.subst}"
        rm -f "${template}"
    done
}

# main
cd "${STAGING_DIR}" || exit 15
# shellcheck disable=SC2044
for _zipBundle in $( find "." -type f -iname \*.zip.subst ) ; do
    echo "exapanding .zip file - ${_zipBundle}"

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

echo "exapanding files..."
cd "${STAGING_DIR}" || exit 15
expandFiles
