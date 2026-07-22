#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test "$(toLower "${PF_CLUSTER_ADMIN_NODES_SYNC_ENABLED}")" = "true" &&
    test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then

    _pf_admin_password="$(get_value PING_IDENTITY_PASSWORD true)"

    # ---- Determine if this node is unseeded --------------------------------
    start_debug_logging
    _statusCode=$(
        curl --insecure --silent \
            --write-out '%{http_code}' --output /tmp/cluster.status \
            --user "${ROOT_USER}:${_pf_admin_password}" \
            --header 'X-XSRF-Header: PingFederate' \
            "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/cluster/status" \
            2> /dev/null
    )
    stop_debug_logging

    _notLicensed="false"
    if test "${_statusCode}" = "403"; then
        _notLicensed=$(jq -r 'if .resultId == "license_agreement_not_accepted" then "true" else "false" end' \
            /tmp/cluster.status 2> /dev/null)
        _notLicensed="${_notLicensed:-false}"
    fi

    if test "${_statusCode}" = "403" && test "${_notLicensed}" = "true"; then
        echo "INFO: Node is unseeded (license not yet accepted). Running initial setup."
        _needs_seed="true"
    elif test "${_statusCode}" = "401"; then
        echo_red "ERROR: HTTP 401 on seed-check — credentials incorrect. Exiting."
        exit 81
    elif test "${_statusCode}" = "403" && test "${_notLicensed}" = "false"; then
        echo "WARN: HTTP 403 but resultId=$(jq -r '.resultId // "unknown"' /tmp/cluster.status 2> /dev/null) — treating as seeded."
        _needs_seed="false"
    else
        echo "INFO: Node is already seeded (HTTP ${_statusCode}). Skipping initial setup."
        _needs_seed="false"
    fi

    # ---- Seed if needed ----------------------------------------------------
    if test "${_needs_seed}" = "true"; then
        run_hook 83-configure-admin.sh
    fi

    # ---- Determine ACTIVE / PASSIVE role -----------------------------------
    # Retry loop: JGroups TCPPING discovery may not yet have propagated an
    # already-active peer into cluster/status at the moment this hook runs.
    # Without retries a fast-starting node sees 0 active peers and self-promotes,
    # producing two simultaneous ACTIVE nodes after a failover/restart.
    echo "INFO: Querying cluster for existing active admin node..."
    _activeCount="0"
    _queryAttempt=0
    _queryMaxAttempts=10
    _queryDelaySecs=3
    while test "${_queryAttempt}" -lt "${_queryMaxAttempts}"; do
        start_debug_logging
        _statusCode=$(
            curl --insecure --silent \
                --write-out '%{http_code}' --output /tmp/cluster.status \
                --user "${ROOT_USER}:${_pf_admin_password}" \
                --header 'X-XSRF-Header: PingFederate' \
                "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/cluster/status" \
                2> /dev/null
        )
        stop_debug_logging

        if test "${_statusCode}" = "200"; then
            _activeCount=$(jq -r '[.nodes[]? | select(.adminConsoleInfo.consoleRole == "ACTIVE")] | length' \
                /tmp/cluster.status 2> /dev/null)
            _activeCount="${_activeCount:-0}"
            if test "${_activeCount}" != "0"; then
                break
            fi
        elif test "${_statusCode}" = "401"; then
            echo_red "ERROR: HTTP 401 querying cluster status — credentials incorrect. Exiting."
            exit 81
        else
            echo "WARN: Could not query cluster status (HTTP ${_statusCode})."
        fi

        _queryAttempt=$((_queryAttempt + 1))
        if test "${_queryAttempt}" -lt "${_queryMaxAttempts}"; then
            echo "INFO: No active admin found yet (attempt ${_queryAttempt}/${_queryMaxAttempts}). Retrying in ${_queryDelaySecs}s..."
            sleep "${_queryDelaySecs}"
        fi
    done

    if test "${_activeCount}" != "0"; then
        echo "INFO: Active admin already present in cluster. This node will remain passive."
        rm -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}"
        exit 0
    fi

    echo "INFO: No active admin in cluster. Promoting this node to active."
    start_debug_logging
    _promoteCode=$(
        curl --insecure --silent \
            --request POST \
            --write-out '%{http_code}' --output /tmp/promote.out \
            --user "${ROOT_USER}:${_pf_admin_password}" \
            --header 'X-XSRF-Header: PingFederate' \
            "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/cluster/adminNode/role/active" \
            2> /dev/null
    )
    stop_debug_logging
    if test "${_promoteCode}" != "200"; then
        echo_red "ERROR ${_promoteCode}: Failed to promote to active admin."
        cat /tmp/promote.out
        exit 81
    fi
    echo "INFO: This node has been promoted to active admin."

    # Wait for promotion to be reflected in heartbeat
    echo "INFO: Waiting for active promotion to take effect..."
    _maxWait=30
    _waited=0
    while test "${_waited}" -lt "${_maxWait}"; do
        _checkCode=$(curl --insecure --silent --write-out '%{http_code}' --output /dev/null \
            "https://localhost:${PF_ADMIN_PORT}/pf/heartbeat.ping?checkActive=true" 2> /dev/null)
        if test "${_checkCode}" = "200"; then
            echo "INFO: Node confirmed active (heartbeat responded 200)."
            break
        fi
        sleep 2
        _waited=$((_waited + 2))
    done
    if test "${_waited}" -ge "${_maxWait}"; then
        echo_red "ERROR: Node did not confirm active state within ${_maxWait}s after promotion."
        exit 81
    fi

else
    # PF_CLUSTER_ADMIN_NODES_SYNC_ENABLED != true — original path
    if test -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}" ||
        test "$(toLower "${CREATE_INITIAL_ADMIN_USER}")" = "true"; then
        run_hook 83-configure-admin.sh
    fi
    if test -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}"; then
        run_hook 85-import-configuration.sh
    fi
    exit 0
fi

# Sync path: only import if this node did the initial seeding AND is now active.
if test "${_needs_seed}" = "true" && test -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}"; then
    run_hook 85-import-configuration.sh
fi
