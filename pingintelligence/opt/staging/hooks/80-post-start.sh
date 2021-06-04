#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook may be used to set the server if there is a setup procedure
#
#- >Note: The PingData (i.e. Directory, DataSync, PingAuthorize, DirectoryProxy)
#- products will all provide this

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=pingintelligence.lib.sh
. "${HOOKS_DIR}/pingintelligence.lib.sh"


while ! isASERunning
do
    sleep 1
done

pi_update_password
test ${?} -ne 0 && echo_red "Error updating password" && exit 80

pi_obfuscate_keys
test ${?} -ne 0 && echo_red "Error obfuscating keys" && exit 80

if test -d "${STAGING_DIR}/apis/"
then
    # this loop will fail with files having whitespaces in their name (or path for that matter)
    # shellcheck disable=SC2044
    for file in $( find "${STAGING_DIR}/apis/" -type f -iname \*.json )
    do
        pi_add_api "${file}"
        test ${?} -ne 0 && exit 80
    done
fi
exit 0
