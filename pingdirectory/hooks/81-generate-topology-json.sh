#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# If a topology.json file is provided externally, then just use that.
if test -f "${TOPOLOGY_FILE}"; then
    echo "${TOPOLOGY_FILE} exists, not generating it"
    exit 0
fi

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=/dev/null
test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

if test -z "${ORCHESTRATION_TYPE}" ; then
    echo "An ORCHESTRATION_TYPE is required to enable replication."
    echo "Possible values include compose, swarm or kubernetes"
    exit 1
fi

# Depending on the type of orchestation used, there are different dns techniques to obtain all the
# hosts for the service.  The following will set the DNS name to be queried.

case "${ORCHESTRATION_TYPE}" in
    COMPOSE)
        if test -z "${COMPOSE_SERVICE_NAME}" ; then
            echo "Variable COMPOSE_SERVICE_NAME is required to enable replication."
            exit 1
        fi
        _topologyServiceName="${COMPOSE_SERVICE_NAME}"
        _seedServer="${COMPOSE_SERVICE_NAME}_1"
        ;;
    # SWARM)
    #     if test -z "${SWARM_SERVICE_NAME}" ; then
    #         echo "Variable SWARM_SERVICE_NAME is required to enable replication."
    #         exit 1
    #     fi
    #     _topologyServiceName="tasks.${SWARM_SERVICE_NAME}"
    #     ;;
    KUBERNETES)
        if test -z "${K8S_STATEFUL_SET_NAME}" -o -z "${K8S_STATEFUL_SET_SERVICE_NAME}" ; then
            echo "Variables K8S_STATEFUL_SET_NAME and K8S_STATEFUL_SET_SERVICE_NAME are required to enable replication."
            exit 1
        fi
        _topologyServiceName="${K8S_STATEFUL_SET_SERVICE_NAME}"
        
        if test "${PD_STATE}" == "SETUP" ; then
            _seedServer="${K8S_STATEFUL_SET_NAME}-0.${DOMAINNAME}"
            echo "Seed server used to enable/init this server in replication is (${_seedServer})"
        fi
        ;;
    *)
        echo "Variable ORCHESTRATION_TYPE (${ORCHESTRATION_TYPE}) not supported."
        exit 1
esac

#
# If no seed server is specified, then we will create a list of all possible servers.
#
# Note: if a seed server is specified, then we MUST enable/init replication from that server
#       to ensure we won't have a split brain scenario with replication toplogies
#
if test -z "${_seedServer}" ; then
    echo "Checking nslookup of ${_topologyServiceName}"
    echo "   1. to see if (${HOSTNAME}) appears"
    echo "   2. There are 2 or more hosts"

    while true; do
        # shellcheck disable=SC2086
        nslookup ${_topologyServiceName}  2>/dev/null | awk '$0 ~ /^Address / {print $4}' >/tmp/_serviceHosts
        _numHosts=$( wc -l </tmp/_serviceHosts 2> /dev/null)

        # cat_indent /tmp/_serviceHosts
        grep "${HOSTNAME}" /tmp/_serviceHosts > /dev/null
        _foundMyself=$?

        test ${_foundMyself} -eq 0 && test ${_numHosts} -gt 1 && break;

        sleep_at_most 15
    done

    echo "Candidate list of servers to enable/init from include:"
    cat_indent /tmp/_serviceHosts
else
    echo "${_seedServer}" >> /tmp/_serviceHosts
fi

#
# We will create a temporary topology file with all hosts other
# than ourselves, and then use that to obtain the official
# topology file from an existing server
#
_tmpTopology="/tmp/_topology.json"

cat > "${_tmpTopology}" <<END
{
  "serverInstances" : [
END

SEPARATOR=""



for _host in $( cat /tmp/_serviceHosts ) ; do
    if test "${_host}" != "${HOSTNAME}" ; then
        # Write the server instance's content
        cat >> "${_tmpTopology}" <<____END
    ${SEPARATOR}{
        "instanceName" : "${_host}",
        "hostname" : "${_host}",
        "location" : "${LOCATION}",
        "ldapPort" : ${LDAP_PORT},
        "ldapsPort" : ${LDAPS_PORT},
        "replicationPort" : ${REPLICATION_PORT},
        "startTLSEnabled" : true,
        "preferredSecurity" : "SSL",
        "product" : "DIRECTORY"
    }
____END
        SEPARATOR=","
    fi
done

cat >> "${_tmpTopology}" <<END
  ]
}
END


rm -rf "${TOPOLOGY_FILE}"

#
# if no seed server specified, then we will get an official topology file from
# one of the existing running servers
# else we will use the seed server toplogy file generated from above
#
if test -z "${_seedServer}" ; then
    #
    # Now use the temporary _topology.json file to obtain
    # an official toplogy file from set of existing running
    # servers
    #
    "${SERVER_ROOT_DIR}"/bin/manage-topology export \
        --topologyFilePath "${_tmpTopology}" \
        --exportFilePath "${TOPOLOGY_FILE}" \
        2>/dev/null >/dev/null
else
    cp -af "${_tmpTopology}" "${TOPOLOGY_FILE}"
fi

if test -f "${TOPOLOGY_FILE}" ; then
    echo "Obtained official ${TOPOLOGY_FILE}"
    cat_indent "${TOPOLOGY_FILE}"
    echo
else
    echo_red "Unable to obtain official topology"
    exit 81
fi