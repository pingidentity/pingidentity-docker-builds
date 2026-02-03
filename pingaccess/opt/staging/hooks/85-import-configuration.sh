#!/usr/bin/env sh
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is started in the background immediately before
#- the server within the container is started
#-
#- This is useful to implement any logic that needs to occur after the
#- server is up and running
#-
#- For example, enabling replication in PingDirectory, initializing Sync
#- Pipes in PingDataSync or issuing admin API calls to PingFederate or PingAccess

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test -f "${STAGING_DIR}/instance/data/data.json"; then
    set -e
    echo_yellow "NOTE: PingAccess 6.1 natively supports data.json ingestion,"
    echo_yellow "and is the recommended method for configuration. For more information, see:"
    echo_yellow "https://devops.pingidentity.com/reference/profileStructures/#pingaccess"

    echo "INFO: Begin importing data.json.."
    api_output_file=$(mktemp)

    # Toggle on debug logging if DEBUG=true is set
    start_debug_logging
    http_response_code=$(
        curl \
            --insecure \
            --silent \
            --write-out '%{http_code}' \
            --request POST \
            --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
            --header "Content-Type: application/json" \
            --header "X-Xsrf-Header: PingAccess" \
            --data @"${STAGING_DIR}/instance/data/data.json" \
            --output "${api_output_file}" \
            "https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import/workflows" \
            2> /dev/null
    )
    # Toggle off debug logging
    stop_debug_logging

    if ! test "${http_response_code}" = "200"; then
        echo_red "ERROR ${http_response_code}: Unable to Import data.json"
        cat "${api_output_file}"
        exit 85
    fi

    import_id=$(jq -r .id "${api_output_file}")
    polling_attempts=300

    # Toggle on debug logging if DEBUG=true is set
    start_debug_logging
    while test ${polling_attempts} -gt 0; do
        http_response_code=$(
            curl \
                --insecure \
                --silent \
                --write-out '%{http_code}' \
                --request GET \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "Content-Type: application/json" \
                --header "X-Xsrf-Header: PingAccess" \
                --output "${api_output_file}" \
                "https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import/workflows" \
                2> /dev/null
        )
        # Toggle off debug logging
        stop_debug_logging

        if test "${http_response_code}" = 200; then
            import_status=$(jq -r '.items[]|select(.id=='"${import_id}"')|.status' "${api_output_file}")
            case "${import_status}" in
                '' | 'In Progress')
                    echo "INFO: Import in progress.."
                    sleep 2
                    ;;
                Complete)
                    echo_green "INFO: Import done."
                    polling_attempts=0
                    ;;
                Failed)
                    # clean failure, display error, bail
                    echo_red "ERROR: Import failed."
                    cat "${api_output_file}"
                    exit 85
                    ;;
                *)
                    # unexpected error
                    echo_red "Import status: ${import_status}"
                    echo_red "ERROR: Unsuccessful Import"
                    exit 85
                    ;;
            esac
        else
            echo "WARN: There was an error retrieving import status, retrying in 3 seconds (HTTP Code: ${http_response_code})"
            # Something is really wrong, retrying at most 3 times
            if test ${polling_attempts} -gt 3; then
                polling_attempts=3
            fi
            sleep 3
        fi
        polling_attempts=$((polling_attempts - 1))
    done

    rm -f "${api_output_file}"
fi

exit 0
