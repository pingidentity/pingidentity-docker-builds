#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This scrip is called to check if there is an existing server
#- and if so, it will return a 1, else 0
#

# shellcheck source=../../pingcommon/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

${VERBOSE} && set -x

rm -rf "${STATE_PROPERTIES}"

RUN_PLAN="UNKNOWN"
PD_STATE="UNKNOWN"
SERVER_UUID_FILE="${SERVER_ROOT_DIR}/config/server.uuid"
ORCHESTRATION_TYPE=$(echo "${ORCHESTRATION_TYPE}" | tr '[:lower:]' '[:upper:]')

if  test -f "${SERVER_UUID_FILE}" ; then
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

# if running in kubernetes
if test "${ORCHESTRATION_TYPE}" = "KUBERNETES" ; then
    if test "$(hostname)" = "${K8S_STATEFUL_SET_NAME}-0" ; then
        # echo "We are the SEED server (${K8S_STATEFUL_SET_NAME})-0"

        if test -z "${serverUUID}" ; then
            nslookup ${K8S_STATEFUL_SET_SERVICE_NAME}  2>/dev/null | awk '$0 ~ /^Address / {print $4}' >/tmp/_serviceHosts
            _numHosts=$( grep -v "$(hostname -f)" /tmp/_serviceHosts | wc -l 2> /dev/null)

            cat /tmp/_serviceHosts
            # echo "Number of other services available = ${_numHosts}"

            if test ${_numHosts} -eq 0 ; then
                PD_STATE="GENESIS"
            fi
        fi
    fi

    echo "
###################################################################################
#
#                      PD_STATE: ${PD_STATE}
#                      RUN_PLAN: ${RUN_PLAN}
#
#            ORCHESTRATION_TYPE: ${ORCHESTRATION_TYPE}
#         K8S_STATEFUL_SET_NAME: ${K8S_STATEFUL_SET_NAME}
# K8S_STATEFUL_SET_SERVICE_NAME: ${K8S_STATEFUL_SET_SERVICE_NAME}
#                      HOSTNAME: ${HOSTNAME}
#                    serverUUID: ${serverUUID}
#" >> "${STATE_PROPERTIES}"

    case "${PD_STATE}" in
        GENESIS)
            echo "#     Startup Plan
#        - manage-profile setup
#        - import data
###################################################################################
" >> "${STATE_PROPERTIES}"

            echo "
##################################################################################
#
#                                   IMPORTANT MESSAGE
#
#                                  GENESIS STATE FOUND
#
# Based on the following information, we have determined that we are the SEED server
# in the GENESIS state (First server to come up in this stateful set) due to the
# folloing conditions:
#
#   1. We couldn't find a valid server.uuid file
#   2. Our host name ($(hostname))is the 1st one in the stateful set (${K8S_STATEFUL_SET_SERVICE_NAME}-0)
#   3. There are no other servers currently running in the stateful set (${K8S_STATEFUL_SET_SERVICE_NAME})
#
# If it is suspected that we shoudn't be in the GENESIS state, take actions to
# remediate.
#
##################################################################################
"
            ;;
        SETUP)
            echo "#     Startup Plan
#        - manage-profile setup
#        - repl enable (from host 0)
#        - repl init   (from host 0)
##################################################################################
" >> "${STATE_PROPERTIES}"
            ;;
        UPDATE)
            echo "#     Startup Plan
#        - manage-profile update
#        - repl enable (from any host)
#        - repl init   (from any host)
##################################################################################
" >> "${STATE_PROPERTIES}"
            ;;
        *)
            container_failure 08 "Unknown PD_STATE of ($PD_STATE)"
    esac
fi
if test "${ORCHESTRATION_TYPE}" = "COMPOSE" ; then
    # Assume GENESIS state for now, if we aren't kubernetes when setting up
    if test "${RUN_PLAN}" = "START" ; then
        PD_STATE="GENESIS"
        nslookup ${COMPOSE_SERVICE_NAME}_1 2>/dev/null | awk '$0 ~ /^Address / {print $4}' | grep ${HOSTNAME} || PD_STATE="SETUP"
    fi
fi

if test -z "${ORCHESTRATION_TYPE}" && test "${PD_STATE}" = "SETUP"; then
    PD_STATE="GENESIS"
fi

test "${RUN_PLAN}" = "RESTART" && PD_STATE="UPDATE"
echo "
###################################################################################
#  
#                      PD_STATE: ${PD_STATE}
#                      RUN_PLAN: ${RUN_PLAN}
#
#            ORCHESTRATION_TYPE: ${ORCHESTRATION_TYPE}
#                      HOSTNAME: ${HOSTNAME}
#                    serverUUID: ${serverUUID}
#
#     Startup Plan
#        - manage-profile setup
#        - import data
###################################################################################
" >> "${STATE_PROPERTIES}"

# Display the new state properties
cat "${STATE_PROPERTIES}"

echo "
ORCHESTRATION_TYPE=${ORCHESTRATION_TYPE}
RUN_PLAN=${RUN_PLAN}

###
# PingDirectory Related State Variables
###

PD_STATE=${PD_STATE}
" >> "${STATE_PROPERTIES}"