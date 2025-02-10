#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook may be used to set the server if there is a setup procedure
#
#- >Note: The PingData (i.e. Directory, DataSync, PingAuthorize, DirectoryProxy)
#- products will all provide this

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=./pingintelligence.lib.sh
. "${HOOKS_DIR}/pingintelligence.lib.sh"

printf "%s" "Waiting for API Security Enforcer to start "
_startCountDown=${PING_STARTUP_TIMEOUT}
_startSuccess=false
while test "${_startCountDown}" -gt 0; do
    _startCountDown=$((_startCountDown - 1))
    if ! isASERunning; then
        printf "%s" "."
        sleep 1
    else
        _startSuccess=true
    fi
done
if test "${_startSuccess}" = "false"; then
    cat "${SERVER_ROOT_DIR}/logs/controller.log" "${SERVER_ROOT_DIR}/logs/balancer*.log"
    echo_red " error."
    exit 80
else
    echo_green " done."
fi

pi_update_password
test ${?} -ne 0 && echo_red "Error updating password" && exit 80

# pi_obfuscate_keys
# test ${?} -ne 0 && echo_red "Error obfuscating keys" && exit 80

if test -d "${STAGING_DIR}/apis/"; then
    # this loop will fail with files having whitespaces in their name (or path for that matter)
    find "${STAGING_DIR}/apis/" -type f -iname \*.json > tmp
    while IFS= read -r file; do
        pi_add_api "${file}"
        test ${?} -ne 0 && exit 80
    done < tmp
    rm tmp
fi

"${SERVER_ROOT_DIR}/bin/cli.sh" status

exit 0
