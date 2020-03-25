#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook runs through the followig phases:
#-
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"
# shellcheck source=pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

#
#- * Ensures the PingDirectoryProxy service has been started an accepts queries.
# 
echo "Waiting until PingDirectoryProxy service is running on this Server (${_podInstanceName})"
echo "        ${_podHostname}:${_podLdapsPort}"
waitUntilLdapUp "${_podHostname}" "${_podLdapsPort}" ""

#
#- * Updates the Server Instance hostname/ldaps-port
#
echo "Updating the Server Instance hostname/ldaps-port:
         instance: ${_podInstanceName}
         hostname: ${_podHostname}
       ldaps-port: ${_podLdapsPort}"

dsconfig set-server-instance-prop --no-prompt --quiet \
    --instance-name "${_podInstanceName}" \
    --set hostname:${_podHostname} \
    --set ldaps-port:${_podLdapsPort}

_updateServerInstanceResult=$?
echo "Updating the Server Instance ${_podInstanceName} result=${_updateServerInstanceResult}"

