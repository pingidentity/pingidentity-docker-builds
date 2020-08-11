#!/usr/bin/env sh
# Ping Identity DevOps - Docker Build Hooks
#
# Prints out variables and startup information when the server is started.
#
# shellcheck source=pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"


# warn about any UNSAFE_ variables
warn_unsafe_variables

echo_header "Container User/Group Info"
echo_vars PING_CONTAINER_PRIVILEGED PING_CONTAINER_UID PING_CONTAINER_GID PING_CONTAINER_UNAME PING_CONTAINER_GNAME

if test "$(toLower "${PING_CONTAINER_PRIVILEGED}")" != "true" ; then
    _failContainer=false
    _failMsg="set to incorrect value.  Please remove."
    test "${PING_CONTAINER_UID}" != "100" && echo_red "PING_CONTIANER_UID ${_failMsg}" && _failContainer=true
    test "${PING_CONTAINER_GID}" != "101" && echo_red "PING_CONTIANER_GID ${_failMsg}" && _failContainer=true
    test "${PING_CONTAINER_UNAME}" != "nginx" && echo_red "PING_CONTIANER_UNAME ${_failMsg}" && _failContainer=true
    test "${PING_CONTAINER_GNAME}" != "nginx" && echo_red "PING_CONTIANER_GNAME ${_failMsg}" && _failContainer=true

    if test "${_failContainer}" = "true" ; then
        echo ""
        echo_red "These variables must be set to default gid/uid (100/101) and uname/gname (nginx/nginx)."
        echo_red "Best option is to remove the setting of these variables."
        echo ""
        container_failure 50 "Resolve issues with above errors."
    fi
fi

echo_header "Ping Federate Info"
echo_vars PF_ENGINE_PUBLIC_HOSTNAME PF_ENGINE_PUBLIC_PORT PF_DELEGATOR_CLIENTI

echo_header "Ping Directory Info"
echo_vars PD_ENGINE_PUBLIC_HOSTNAME PD_ENGINE_PUBLIC_PORT

echo_header "Ping Delegator Info"
echo_vars PD_DELEGATOR_TIMEOUT_LENGTH_MINS PD_DELEGATOR_HEADER_BAR_LOGO PD_DELEGATOR_DADMIN_API_NAMESPACE PD_DELEGATOR_PROFILE_SCOPE_ENABLED
