#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# check if admin password is to be changed by looking for an 'initial' password
if test -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}" || test "$(toLower "${CREATE_INITIAL_ADMIN_USER}")" = "true"; then
    run_hook 83-configure-admin.sh
fi

# When active/passive multi-admin is enabled, determine if this node should
# run the bulk config import or defer to synchronization from the active node.
#
# This block runs after 83-configure-admin.sh so admin credentials exist for
# the API calls, but before 85-import-configuration.sh so import only runs
# on the active node.
if test "$(toLower "${PF_CLUSTER_ADMIN_NODES_SYNC_ENABLED}")" = "true" \
    && test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then

    _pf_admin_password="$(get_value PING_IDENTITY_PASSWORD true)"
    if test -z "${_pf_admin_password}"; then
        echo_yellow "WARN: No PING_IDENTITY_PASSWORD variable found. Using default password."
        _pf_admin_password="2Federate"
    fi

    # Always query cluster status first to detect an existing active admin.
    # This correctly handles pod-0 restarts after a failover to pod-1.
    echo "INFO: Querying cluster for existing active admin node..."
    _statusCode=$(
        curl --insecure --silent \
            --write-out '%{http_code}' --output /tmp/cluster.status \
            --user "${ROOT_USER}:${_pf_admin_password}" \
            --header 'X-XSRF-Header: PingFederate' \
            "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/cluster/status" \
            2>/dev/null
    )

    if test "${_statusCode}" = "200"; then
        _activeCount=$(jq -r '[.nodes[]? | select(.adminConsoleInfo.consoleRole == "ACTIVE")] | length' /tmp/cluster.status 2>/dev/null)
        _activeCount="${_activeCount:-0}"
    else
        echo "WARN: Could not query cluster status (HTTP ${_statusCode}). Assuming no active admin."
        _activeCount="0"
    fi

    if test "${_activeCount}" != "0"; then
        # An active admin already exists in the cluster — this node stays passive.
        # This covers: pod-0 restarting after failover, or pod-N joining an established cluster.
        echo "INFO: Active admin already present in cluster. This node will remain passive."
        echo "INFO: Passive admin node — skipping bulk config import."
        exit 0
    fi

    # No active admin found. Use pod ordinal as tiebreaker:
    # ordinal 0 promotes; any other ordinal stays passive and waits for pod-0.
    _pod_ordinal=$(echo "${HOSTNAME:-}" | sed 's/.*-//')
    if echo "${_pod_ordinal}" | grep -qE '^[0-9]+$' && test "${_pod_ordinal}" = "0"; then
        echo "INFO: No active admin in cluster and pod ordinal is 0. Promoting this node to active."
    else
        echo "INFO: No active admin in cluster but pod ordinal is not 0 (${_pod_ordinal}). Staying passive; pod-0 will promote."
        echo "INFO: Passive admin node — skipping bulk config import."
        exit 0
    fi

    # Promote this node to active.
    # The promote endpoint takes no request body.
    _promoteCode=$(
        curl --insecure --silent \
            --request POST \
            --write-out '%{http_code}' --output /tmp/promote.out \
            --user "${ROOT_USER}:${_pf_admin_password}" \
            --header 'X-XSRF-Header: PingFederate' \
            "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/cluster/adminNode/role/active" \
            2>/dev/null
    )
    if test "${_promoteCode}" != "200"; then
        echo_red "ERROR ${_promoteCode}: Failed to promote this node to active admin."
        cat /tmp/promote.out
        exit 81
    fi
    echo "INFO: This node has been promoted to active admin."

    # Wait for the promotion to take effect before proceeding with bulk import.
    # Passive nodes respond 403 to checkActive=true; active nodes respond 200.
    echo "INFO: Waiting for active promotion to take effect..."
    _maxWait=30
    _waited=0
    while test "${_waited}" -lt "${_maxWait}"; do
        _checkCode=$(curl --insecure --silent --write-out '%{http_code}' --output /dev/null \
            "https://localhost:${PF_ADMIN_PORT}/pf/heartbeat.ping?checkActive=true" 2>/dev/null)
        if test "${_checkCode}" = "200"; then
            echo "INFO: Node confirmed active (heartbeat responded 200)."
            break
        fi
        sleep 2
        _waited=$(( _waited + 2 ))
    done
    if test "${_waited}" -ge "${_maxWait}"; then
        echo_red "ERROR: Node did not confirm active state within ${_maxWait}s after promotion."
        exit 81
    fi
fi

# check for bulk config import file
if test -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}"; then
    run_hook 85-import-configuration.sh
fi
