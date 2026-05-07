#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# When active/passive multi-admin is enabled, determine role BEFORE calling
# hook 83 — the license agreement endpoint (used by 83) returns 403 on a
# passive node, which would cause a container failure.
#
# Decision: use pod ordinal as the initial active/passive split on first start.
# Non-zero ordinal nodes exit passive immediately, skipping both 83 and 85.
# Ordinal-0 proceeds to run 83 (creates admin credentials), then queries
# cluster status to handle the restart-after-failover case.
if test "$(toLower "${PF_CLUSTER_ADMIN_NODES_SYNC_ENABLED}")" = "true" &&
	test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then

	_pod_ordinal=$(hostname | sed 's/.*-//')
	if echo "${_pod_ordinal}" | grep -qE '^[0-9]+$' && test "${_pod_ordinal}" != "0"; then
		echo "INFO: Pod ordinal ${_pod_ordinal} — this is a passive admin node. Skipping configuration hooks."
		exit 0
	fi
	if ! echo "${_pod_ordinal}" | grep -qE '^[0-9]+$'; then
		echo "INFO: Non-numeric pod ordinal (${_pod_ordinal}) — staying passive. StatefulSet with ordinal hostnames is required for multi-admin."
		exit 0
	fi
	# Ordinal 0 falls through to hook 83 below.
fi

# check if admin password is to be changed by looking for an 'initial' password
if test -f "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}" || test "$(toLower "${CREATE_INITIAL_ADMIN_USER}")" = "true"; then
	run_hook 83-configure-admin.sh
fi

# After 83, admin credentials exist. Now check cluster status to determine
# whether to promote (first start) or stay passive (restart after failover).
if test "$(toLower "${PF_CLUSTER_ADMIN_NODES_SYNC_ENABLED}")" = "true" &&
	test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then

	_pf_admin_password="$(get_value PING_IDENTITY_PASSWORD true)"
	if test -z "${_pf_admin_password}"; then
		echo_yellow "WARN: No PING_IDENTITY_PASSWORD variable found. Using default password."
		_pf_admin_password="2Federate"
	fi

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
		# Active admin already exists — pod-0 restarted after a failover to another node.
		echo "INFO: Active admin already present in cluster. This node will remain passive."
		echo "INFO: Passive admin node — skipping bulk config import."
		exit 0
	fi

	echo "INFO: No active admin in cluster. Promoting this node to active."
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

	# Wait for the promotion to take effect before bulk import.
	# Active node responds 200; passive responds 403.
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
		_waited=$((_waited + 2))
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
