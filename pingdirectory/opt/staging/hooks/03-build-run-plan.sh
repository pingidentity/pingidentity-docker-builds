#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is called to check if there is an existing server
#- and if so, it will return a 1, else 0
#

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=pingdirectory.lib.sh
. "${HOOKS_DIR}/pingdirectory.lib.sh"

${VERBOSE} && set -x

rm -rf "${STATE_PROPERTIES}"

#
#- Goal of building a run plan is to provide a plan for the server as it starts up
#- Options for the RUN_PLAN and the PD_STATE are as follows:
#-
#- RUN_PLAN (Initially set to UNKNOWN)
#-          START   - Instructs the container to start from scratch.  This is primarily
#-                    because a server.uuid file is not present.
#-          RESTART - Instructs the container to restart an existing directory.  This is
#-                    primarily because an existing server.uuid file is prsent.
#- 
#- PD_STATE (Initially set to UNKNOWN)
#-          SETUP   - Specifies that the server should be setup
#-          UPDATE  - Specifies that the server should be updated
#-          GENISIS - A very special case when the server is determined to be the
#-                    SEED Server and initial server should be setup and data imported
RUN_PLAN="UNKNOWN"
PD_STATE="UNKNOWN"
SERVER_UUID_FILE="${SERVER_ROOT_DIR}/config/server.uuid"
ORCHESTRATION_TYPE=$(echo "${ORCHESTRATION_TYPE}" | tr '[:lower:]' '[:upper:]')

# Create a temporary file that will be used to store output as items are determined
_planFile="/tmp/plan-${ORCHESTRATION_TYPE}.txt"
rm -rf "${_planFile}"

# If we have a server.uuid file, then the container should RESTART with an UPDATE plan
# If we don't have a server.uuid file, then we should START with a SETUP plan.  Additionally
#    if a SERVER_ROOT_DIR is found, then we should cleanup before starting.
if  test -f "${SERVER_UUID_FILE}" ; then
    # Sets the serverUUID variable
    . "${SERVER_UUID_FILE}"

    RUN_PLAN="RESTART"
    PD_STATE="UPDATE"
else
    RUN_PLAN="START"
    PD_STATE="SETUP"

    if test -d "${SERVER_ROOT_DIR}" ; then
        echo "No server.uuid found. Removing existing SERVER_ROOT_DIR '${SERVER_ROOT_DIR}''"
        rm -rf "${SERVER_ROOT_DIR}"
    fi
fi

#
# Create all the POD Server details
#
_podName=$(hostname)
_ordinal=$(echo ${_podName##*-})


_podHostname="$(hostname)"
_podInstanceName="${_podHostname}"
_podLocation="${LOCATION}"
_podLdapsPort="${LDAPS_PORT}"
_podReplicationPort="${REPLICATION_PORT}"

echo "
###################################################################################
#            ORCHESTRATION_TYPE: ${ORCHESTRATION_TYPE}
#                      HOSTNAME: ${HOSTNAME}
#                    serverUUID: ${serverUUID}
#" >> "${_planFile}"

#########################################################################
# KUBERNETES ORCHESTRATION_TYPE
#########################################################################
if test "${ORCHESTRATION_TYPE}" = "KUBERNETES" ; then

    if test -z "${K8S_STATEFUL_SET_NAME}"; then
        container_failure "03" "KUBERNETES Orchestation ==> K8S_STATEFUL_SET_NAME required"
    fi

    if test -z "${K8S_STATEFUL_SET_SERVICE_NAME}"; then
        container_failure "03" "KUBERNETES Orchestation ==> K8S_STATEFUL_SET_SERVICE_NAME required"
    fi

    #
    # Check to see if we have the variables for single or multi cluster replication
    #
    # If we have both K8S_CLUSTER and K8S_SEED_CLUSTER defined then we are in a 
    # multi cluster mode.
    #
    if test -z "${K8S_CLUSTERS}" ||
       test -z "${K8S_CLUSTER}" ||
       test -z "${K8S_SEED_CLUSTER}"; then
        _clusterMode="single"

        if test ! -z "${K8S_CLUSTERS}" ||
           test ! -z "${K8S_CLUSTER}" ||
           test ! -z "${K8S_SEED_CLUSTER}"; then
            echo "One of K8S_CLUSTERS (${K8S_CLUSTERS}), K8S_CLUSTER (${K8S_CLUSTER}), K8S_SEED_CLUSTER (${K8S_SEED_CLUSTER}) aren't set."
            echo "All or none of these must be set."
            container_failure "03" "KUBERNETES Orchestation ==> All or none of K8S_CLUSTERS K8S_CLUSTER K8S_SEED_CLUSTER required"
        fi
    else
        _clusterMode="multi"

        if test -z "${K8S_POD_HOSTNAME_PREFIX}"; then
            echo "K8S_POD_HOSTNAME_PREFIX not set.  Defaulting to K8S_STATEFUL_SET_NAME- (\${K8S_STATEFUL_SET_NAME}-)"
            K8S_POD_HOSTNAME_PREFIX="${K8S_STATEFUL_SET_NAME}-"
        fi

        if test -z "${K8S_POD_HOSTNAME_SUFFIX}"; then
            echo "K8S_POD_HOSTNAME_SUFFIX not set.  Defaulting to K8S_CLUSTER (.\${K8S_CLUSTER})"
            K8S_POD_HOSTNAME_SUFFIX=".\${K8S_CLUSTER}"
        fi

        if test -z "${K8S_SEED_HOSTNAME_SUFFIX}"; then
            echo "K8S_SEED_HOSTNAME_SUFFIX not set.  Defaulting to K8S_SEED_CLUSTER (.\${K8S_SEED_CLUSTER})"
            K8S_SEED_HOSTNAME_SUFFIX=".\${K8S_SEED_CLUSTER}"
        fi

        if test ${K8S_INCREMENT_PORTS} = true; then
            _incrementPortsMsg="Using different ports for each instance, incremented from LDAPS_PORT (${LDAPS_PORT}) and REPLICATION_PORT (${REPLICATION_PORT})"
        else
            _incrementPortsMsg="K8S_INCREMENT_PORTS not used ==> Using same ports for all instancesLDAPS_PORT (${LDAPS_PORT}) and REPLICATION_PORT (${REPLICATION_PORT})"
        fi
    fi

    _seedLdapsPort="${LDAPS_PORT}"
    _seedReplicationPort="${REPLICATION_PORT}"

    #
    # Single Cluster Details
    #
    # Create an instance/hostname using the Kubernetes StatefulSet Name and Service Name
    if test "${_clusterMode}" = "single"; then
        _podInstanceName="${K8S_STATEFUL_SET_NAME}-${_ordinal}.${K8S_STATEFUL_SET_SERVICE_NAME}"
        _podHostname=${_podInstanceName}
        _podLocation="${LOCATION}"

        _seedInstanceName="${K8S_STATEFUL_SET_NAME}-0.${K8S_STATEFUL_SET_SERVICE_NAME}"
        _seedHostname=${_seedInstanceName}
        _seedLocation="${LOCATION}"
    fi

    #
    # Multi Cluster Details
    #
    # Create an instance/hostname using the Kubernetes Cluster and Suffixes provided
    if test "${_clusterMode}" = "multi"; then
        _podInstanceName="${K8S_STATEFUL_SET_NAME}-${_ordinal}.${K8S_CLUSTER}"
        _podHostname=$(eval "echo ${K8S_POD_HOSTNAME_PREFIX}${_ordinal}${K8S_POD_HOSTNAME_SUFFIX}")
        _podLocation="${K8S_CLUSTER}"

        _seedInstanceName="${K8S_STATEFUL_SET_NAME}-0.${K8S_SEED_CLUSTER}"
        _seedHostname=$(eval "echo ${K8S_POD_HOSTNAME_PREFIX}0${K8S_SEED_HOSTNAME_SUFFIX}")
        _seedLocation="${K8S_SEED_CLUSTER}"


        if test "${K8S_INCREMENT_PORTS}" = "true"; then
            _podLdapsPort=$(( LDAPS_PORT + _ordinal ))
            LDAPS_PORT=${_podLdapsPort}
            _podReplicationPort=$(( REPLICATION_PORT + _ordinal ))
            REPLICATION_PORT=${_podReplicationPort}
        fi
    fi

    if test "${_podInstanceName}" = "${_seedInstanceName}" ; then
        echo "We are the SEED server (${_seedInstanceName})"

        if test -z "${serverUUID}" ; then
            #
            # First, we will check to see if there are any servers available in
            # existing cluster
            _numHosts=$( getIPsForDomain ${K8S_STATEFUL_SET_SERVICE_NAME} | wc -w 2>/dev/null )
            
            echo "Number of servers available in this domain: ${_numHosts}"

            if test ${_numHosts} -eq 0 ; then
                #
                # Second, we need to check other clusters
                if test "${_clusterMode}" = "multi"; then
                    echo_red "We need to check all 0 servers in each cluster"
                fi

                PD_STATE="GENESIS"
            fi
        fi
    fi

    echo "#
#         K8S_STATEFUL_SET_NAME: ${K8S_STATEFUL_SET_NAME}
# K8S_STATEFUL_SET_SERVICE_NAME: ${K8S_STATEFUL_SET_SERVICE_NAME}
#
#                  K8S_CLUSTERS: ${K8S_CLUSTERS}  (${_clusterMode} cluster)
#                   K8S_CLUSTER: ${K8S_CLUSTER}  
#              K8S_SEED_CLUSTER: ${K8S_SEED_CLUSTER}
#              K8S_NUM_REPLICAS: ${K8S_NUM_REPLICAS}
#       K8S_POD_HOSTNAME_PREFIX: ${K8S_POD_HOSTNAME_PREFIX}
#       K8S_POD_HOSTNAME_SUFFIX: ${K8S_POD_HOSTNAME_SUFFIX}
#      K8S_SEED_HOSTNAME_SUFFIX: ${K8S_SEED_HOSTNAME_SUFFIX}
#           K8S_INCREMENT_PORTS: ${K8S_INCREMENT_PORTS} (${_incrementPortsMsg})
#
#" >> "${_planFile}"

fi

#########################################################################
# COMPOSE ORCHESTRATION_TYPE
#########################################################################
if test "${ORCHESTRATION_TYPE}" = "COMPOSE" ; then
    # Assume GENESIS state for now, if we aren't kubernetes when setting up
    if test "${RUN_PLAN}" = "START" ; then
        PD_STATE="GENESIS"

        #
        # Check to see 
        if test $(getIP ${COMPOSE_SERVICE_NAME}_1) != \
                $(getIP ${HOSTNAME}); then
           echo "We are the SEED Server"
           PD_STATE="SETUP"
        fi
    fi

    if test -z "${COMPOSE_SERVICE_NAME}" ; then
        echo "Replication will not be enabled."
        echo "Variable COMPOSE_SERVICE_NAME is required to enable replication."
    else
        _seedHostname="${COMPOSE_SERVICE_NAME}_1"
        _seedInstanceName="${COMPOSE_SERVICE_NAME}"
        _seedLocation="${LOCATION}"
        _seedLdapsPort="${LDAPS_PORT}"
        _seedReplicationPort="${REPLICATION_PORT}"
    fi
fi

#########################################################################
# DIRECTED ORCHESTRATION_TYPE
#########################################################################
if test "${ORCHESTRATION_TYPE}" = "DIRECTED" ; 
then
    if test "${RUN_PLAN}" = "START" ; 
    then
        # When the RUN_PLAN is for a fresh start (vs a restart of a container) 
        if test -z "${REPLICATION_SEED_HOST}" ;
        then
            # either it is a genesis event for a standalone container
            # or the first container of a topology
            PD_STATE="GENESIS"
        else
            # OR the container is directed to replicate from a seed host
            PD_STATE="SETUP"
        fi
    fi

    _seedHostname="${REPLICATION_SEED_HOST}"
    _seedInstanceName="${REPLICATION_SEED_NAME:-${REPLICATION_SEED_HOST}}"
    _seedLocation="${REPLICATION_SEED_LOCATION:-${LOCATION}}"
    _seedLdapsPort="${REPLICATION_SEED_LDAPS_PORT:-${LDAPS_PORT}}"
    _seedReplicationPort="${REPLICATION_SEED_REPLICATION_PORT:-${REPLICATION_PORT}}"
fi


#########################################################################
# Unkown ORCHESTRATION_TYPE
#########################################################################
if test -z "${ORCHESTRATION_TYPE}" && test "${PD_STATE}" = "SETUP"; then
    echo "Replication will not be enabled. Unknown ORCHESTRATION_TYPE"
    PD_STATE="GENESIS"
fi

#
# Print out different messages/startup plans based on the PD_STATE
# If the PD_STATE is not set to a known state, then we have a container failure
#
case "${PD_STATE}" in
    GENESIS)
        echo "#     Startup Plan
#        - manage-profile setup
#        - import data" >> "${_planFile}"

        echo "
##################################################################################
#
#                                   IMPORTANT MESSAGE
#
#                                  GENESIS STATE FOUND
#
# If it is suspected that we shoudn't be in the GENESIS state, take actions to
# remediate.
#
# Based on the following information, we have determined that we are the SEED server
# in the GENESIS state (First server to come up in this stateful set) due to the
# folloing conditions:
#
#   1. We couldn't find a valid server.uuid file"

        test "${ORCHESTRATION_TYPE}" = "KUBERNETES" && echo "#
#   2. KUBERNETES - Our host name ($(hostname))is the 1st one in the stateful set (${K8S_STATEFUL_SET_SERVICE_NAME}-0)
#   3. KUBERNETES - There are no other servers currently running in the stateful set (${K8S_STATEFUL_SET_SERVICE_NAME})"

        test "${ORCHESTRATION_TYPE}" = "COMPOSE" && echo "#
#   2. COMPOSE - Our host name ($(hostname)) has the same IP address as the
                 first host in the COMPOSE_SERVICE_NAME (${COMPOSE_SERVICE_NAME}_1)"
echo "#
##################################################################################
"
        ;;
    SETUP)
        echo "#     Startup Plan
#        - manage-profile setup
#        - repl enable (from SEED Server-${_seedInstanceName})
#        - repl init   (from topology.json, from SEED Server-${_seedInstanceName})" >> "${_planFile}"
        ;;
    UPDATE)
        echo "#     Startup Plan
#        - manage-profile update
#        - repl enable (from SEED Server-${_seedInstanceName})
#        - repl init   (from topology.json, from SEED Server-${_seedInstanceName})" >> "${_planFile}"
        ;;
    *)
        container_failure 08 "Unknown PD_STATE of ($PD_STATE)"
esac

echo "
###################################################################################
#  
#                      PD_STATE: ${PD_STATE}
#                      RUN_PLAN: ${RUN_PLAN}
#" >> "${STATE_PROPERTIES}"

cat "${_planFile}" >> "${STATE_PROPERTIES}"

echo "###################################################################################
#
# POD Server Information
#                 instance name: ${_podInstanceName}
#                      hostname: ${_podHostname}
#                      location: ${_podLocation}
#                    ldaps port: ${_podLdapsPort}
#              replication port: ${_podReplicationPort}
#
# SEED Server Information
#                 instance name: ${_seedInstanceName}
#                      hostname: ${_seedHostname}
#                      location: ${_seedLocation}
#                    ldaps port: ${_seedLdapsPort}
#              replication port: ${_seedReplicationPort}
###################################################################################
" >> "${STATE_PROPERTIES}"



#########################################################################
# print out a table of all the pods and clusters if we have the proper variables
# defined
#########################################################################
if test ! -z "${K8S_CLUSTERS}" &&
   test ! -z "${K8S_NUM_REPLICAS}"; then
    _numReplicas=${K8S_NUM_REPLICAS}
    _clusterWidth=0
    _podWidth=0
    _portWidth=5

    #
    # First, we will calculate a bunch of sizes so we can print in a pretty table
    # and place all the vlues into a row array to be printed in a loop later on
    #
    for _cluster in ${K8S_CLUSTERS}; do
        # get the max size of cluster name
        test ${#_cluster} -gt ${_clusterWidth} && _clusterWidth=${#_cluster}

        i=0
        while (test $i -lt ${_numReplicas}) ; do
            _pod="${K8S_STATEFUL_SET_NAME}-${_ordinal}.${_cluster}"

            # get the max size of the pod name
            test ${#_pod} -gt ${_podWidth} && _podWidth=${#_pod}

            _ldapsPort=${_seedLdapsPort}
            _replicationPort=${_seedReplicationPort}
            if test ${K8S_INCREMENT_PORTS} = true; then
                _ldapsPort=$((_ldapsPort+i))
                _replicationPort=$((_replicationPort+i))
            fi

            i=$((i+1))
        done
    done


    # Get the total width of each row and the width of the cluster header rows
    totalWidth=$((_podWidth+_portWidth+_portWidth+11))
    _clusterWidth=$((totalWidth-14))

    # The following are some variables used for printf format statements
    _dashes="--------------------------------------------------------------------------------"
    _seperatorRow=$(printf "# +------+------+-%.${_podWidth}s-+-%.${_portWidth}s-+-%.${_portWidth}s-+\n" \
        "${_dashes}" "${_dashes}" "${_dashes}")
    _clusterFormat="# | %-4s   %-4s | CLUSTER: %-${_clusterWidth}s |\n"
    _podFormat="# | %-4s | %-4s | %-${_podWidth}s | %-${_portWidth}s | %-${_portWidth}s |\n"

    # print out the top header for the table
    echo "${_seperatorRow}" >> "${STATE_PROPERTIES}"
    printf "${_podFormat}" "SEED" "POD" "Instance" "LDAPS" "REPL" >> "${STATE_PROPERTIES}"

    # Print each row
    for _cluster in ${K8S_CLUSTERS}; do
        _ordinal=0

        while (test $_ordinal -lt ${_numReplicas}) ; do
            _pod="${K8S_STATEFUL_SET_NAME}-${_ordinal}.${_cluster}"
            
            # If we are printing a row representing the seed pod
            _seedIndicator=""
            test "${_cluster}" = "${K8S_SEED_CLUSTER}" && \
            test "${_ordinal}" = "0" && \
            _seedIndicator="***"

            
            # If we are printing a row representing the current pod, then we will
            # provide an indicator of that
            _podIndicator=""
            test "${_podInstanceName}" = "${_pod}" && _podIndicator="***"

            _ldapsPort=${LDAPS_PORT}
            _replicationPort=${REPLICATION_PORT}
            if test ${K8S_INCREMENT_PORTS} = true; then
                _ldapsPort=$((_ldapsPort+_ordinal))
                _replicationPort=$((_replicationPort+_ordinal))
            fi

            # As we print the rows, if we are a new cluster, then we'll print a new cluster
            # header row
            if test "${_prevCluster}" != "${_cluster}"; then
                echo "${_seperatorRow}" >> "${STATE_PROPERTIES}"
                printf "${_clusterFormat}" "${_seedIndicator}" "" "${_cluster}" >> "${STATE_PROPERTIES}"
                echo "${_seperatorRow}" >> "${STATE_PROPERTIES}"
            fi
            _prevCluster=${_cluster}
            
            printf "${_podFormat}" "${_seedIndicator}" "${_podIndicator}" "${_pod}" "${_ldapsPort}" "${_replicationPort}" >> "${STATE_PROPERTIES}"

            _ordinal=$((_ordinal+1))
        done
    done

    echo "${_seperatorRow}" >> "${STATE_PROPERTIES}"
fi

# Print out all the STATE_POPERTIES
cat "${STATE_PROPERTIES}"

echo "
###
# PingDirectory orchestration, run plan and current state
###
ORCHESTRATION_TYPE=${ORCHESTRATION_TYPE}
RUN_PLAN=${RUN_PLAN}
PD_STATE=${PD_STATE}
INSTANCE_NAME=${_podInstanceName}

###
# POD Server Info
###
_podInstanceName=${_podInstanceName}
_podHostname=${_podHostname}
_podLocation=${_podLocation}
_podLdapsPort=${_podLdapsPort}
_podReplicationPort=${_podReplicationPort}

###
# SEED Server Info
###
_seedInstanceName=${_seedInstanceName}
_seedHostname=${_seedHostname}
_seedLocation=${_seedLocation}
_seedLdapsPort=${_seedLdapsPort}
_seedReplicationPort=${_seedReplicationPort}

LDAPS_PORT=${LDAPS_PORT}
LOCATION=${_podLocation}
REPLICATION_PORT=${REPLICATION_PORT}
" >> "${CONTAINER_ENV}"
