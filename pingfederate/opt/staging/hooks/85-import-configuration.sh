#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

pf_admin_password="$(get_value PING_IDENTITY_PASSWORD true)"
if test -z "${pf_admin_password}"; then
    echo_yellow "WARN: No PING_IDENTITY_PASSWORD variable found. Using default password"
    pf_admin_password="2Federate"
fi

tmp_trace_file=$(mktemp)
api_output_file=$(mktemp)
#TODO remove --trace command when curl is fixed with a timeout error when sending large json data sets
# Toggle on debug logging if DEBUG=true is set
start_debug_logging
http_response_code=$(
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --request POST \
        --user "${ROOT_USER}:${pf_admin_password}" \
        --header 'Content-Type: application/json' \
        --header 'X-XSRF-Header: PingFederate' \
        --header 'X-BypassExternalValidation: true' \
        --data "@${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}" \
        --output "${api_output_file}" \
        --trace "${tmp_trace_file}" \
        "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/bulk/import?failFast=false" \
        2> /dev/null
)
# Toggle off debug logging
stop_debug_logging

rm -f "${tmp_trace_file}"

if test "${http_response_code}" = "200"; then
    echo "INFO: Removing Imported Bulk File"
    rm "${BULK_CONFIG_DIR}/${BULK_CONFIG_FILE}"

    # Toggle on debug logging if DEBUG=true is set
    start_debug_logging
    if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then
        http_response_code=$(
            curl \
                --insecure \
                --silent \
                --write-out '%{http_code}' \
                --request POST \
                --user "${ROOT_USER}:${pf_admin_password}" \
                --header 'Content-Type: application/json' \
                --header 'X-XSRF-Header: PingFederate' \
                --output "${api_output_file}" \
                "https://localhost:${PF_ADMIN_PORT}/pf-admin-api/v1/cluster/replicate" \
                2> /dev/null
        )
        # Toggle off debug logging
        stop_debug_logging

        if test "${http_response_code}" != "200"; then
            echo_red "ERROR ${http_response_code}: Unable to replicate config"
            cat "${api_output_file}"
            exit 85
        fi
    fi
else
    echo_red "ERROR ${http_response_code}: Unable to import bulk config"
    cat "${api_output_file}"
    exit 85
fi

rm -f "${api_output_file}"
exit 0
