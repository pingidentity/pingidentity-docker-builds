#!/usr/bin/env sh
#
# Ping Identity DevOps - Ping Intelligence Liveness Check
#
${VERBOSE} && set -x

# shellcheck source=../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=staging/hooks/pingintelligence.lib.sh
. "${HOOKS_DIR}/pingintelligence.lib.sh"

# This liveness probe checks that everything configued is actually responding appropriately
# This includes, in this order:
#   - the HTTPS listener
#   - the HTTP listener
#   - the management listener
#   - the cluster management port

check_available_url ()
{
    test -z "${1}" && echo "empty URL" && exit 1
    _url="${1}"
    curl -sSk --ipv4 -o /dev/null "${_url}"
    if test ${?} -eq 0
    then
        echo_green "ASE availability confirmed on ${_url}"
    else
        echo_red "ASE unavailable at ${_url}"
        exit 1
    fi
}

check_available_tcp ()
{
    test -z "${1}" && echo "empty target" && exit 1
    _target="${1}"
    wait-for "${_target}" -t 5
    if test ${?} -eq 0
    then
        echo_green "ASE availability confirmed on tcp ${_target}"
    else
        echo_red "ASE unavailable at tcp ${_target}"
        exit 1
    fi
}

set -e

health=$( pi_get_config ase enable_ase_health )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1

# if configured, check the HTTPS port is live
https_port=$( pi_get_config ase https_wss_port )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1
if test -n "${https_port}"
then
    if test "${health}" = "true"
    then
        # ping against health check service on HTTP
        check_available_url "https://localhost:${https_port}/ase"
    else
        # simple check if the port is open
        check_available_tcp "localhost:${https_port}"
    fi
fi

# If configured, check on the HTTP too
http_port=$( pi_get_config ase http_ws_port )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1

if test -n "${http_port}"
then
    if test "${health}" = "true"
    then
        # ping against health check service on HTTP
        check_available_url "http://localhost:${http_port}/ase"
    else
        # simple check if the port is open
        check_available_tcp "localhost:${http_port}"
    fi
fi

# let's check if the management port is configured (it should always be)
management_port=$( pi_get_config ase management_port )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1
if test -n "${management_port}"
then
    check_available_tcp "localhost:${management_port}"
fi

cluster_enabled=$( pi_get_config ase enable_cluster )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1

cluster_port=$( pi_get_config cluster cluster_manager_port )
test ${?} -ne 0 && echo "error parsing cluster configuration" && exit 1
if test "${cluster_enabled}" = "true" && test -n "${cluster_port}"
then
    check_available_tcp "localhost:${cluster_port}" -t 5
fi

test isASERunning || exit 1

# ASE is firing on all cylinders!
exit 0