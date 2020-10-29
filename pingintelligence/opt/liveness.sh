#!/usr/bin/env sh
#
# Ping Identity DevOps - Ping Intelligence Liveness Check
#
${VERBOSE} && set -x

# This liveness probe checks that everything configued is actually responding appropriately
# This includes, in this order:
#   - the HTTPS listener
#   - the HTTP listener
#   - the management listener
#   - the cluster management port

ase_conf="${SERVER_ROOT_DIR}/config/ase.conf"
cluster_conf="${SERVER_ROOT_DIR}/config/cluster.conf"

! test -f "${ase_conf}" && echo "ASE configuration not found" && exit 1
! test -f "${cluster_conf}" && echo "Clusterr configuration not fond" && exit 1

health=$( awk -F= '$0~/^enable_ase_health=/{print $2}' "${ase_conf}" )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1

# if configured, check the HTTPS port is live
https_port=$( awk -F= '$0~/^https_wss_port=/{print $2}' "${ase_conf}" )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1
if test -n "${https_port}"
then
    if test "${health}" = "true"
    then
        # ping against health check service on HTTP
        curl -sSk --ipv4 -o /dev/null "https://localhost:${https_port}/ase" || exit 1
    else
        # simple check if the port is open
        wait-for "localhost:${https_port}" -t 5 || exit 1
    fi
fi

# If configured, check on the HTTP too
http_port=$( awk -F= '$0~/^http_ws_port=/{print $2}' "${ase_conf}" )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1

if test -n "${http_port}"
then
    if test "${health}" = "true"
    then
        # ping against health check service on HTTP
        curl -sSk --ipv4 -o /dev/null "http://localhost:${http_port}/ase" || exit 1
    else
        # simple check if the port is open
        wait-for "localhost:${http_port}" -t 5 || exit 1
    fi
fi

# let's check if the management port is configured
management_port=$( awk -F= '$0~/^management_port=/{print $2}' "${ase_conf}" )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1
if test -n "${management_port}"
then
    wait-for "localhost:${management_port}" -t 5 || exit 1
fi

cluster_enabled=$( awk -F= '$0~/^enable_cluster=/{print $2}' "${ase_conf}" )
test ${?} -ne 0 && echo "error parsing ASE configuration" && exit 1

cluster_port=$( awk -F= '$0~/^cluster_manager_port=/{print $2}' "${cluster_conf}" )
test ${?} -ne 0 && echo "error parsing cluster rconfiguration" && exit 1
if test "${cluster_enabled}" = "true" && test -n "${cluster_port}"
then
    wait-for "localhost:${cluster_port}" -t 5 || exit 1
fi

# ASE is firing on all cylinders!
exit 0