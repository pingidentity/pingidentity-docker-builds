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

api_output_file=$(mktemp)
engine_configuration_zip_file=$(mktemp)
pa_host=${PA_CONSOLE_HOST}
pa_port=${PA_ADMIN_PORT}
# The environment variables PA_ADMIN_PRIVATE_... are automatically created from
# ping-devops helm charts
test -n "${PA_ADMIN_PRIVATE_HOSTNAME}" && pa_host=${PA_ADMIN_PRIVATE_HOSTNAME}
test -n "${PA_ADMIN_PRIVATE_PORT_HTTPS}" && pa_port=${PA_ADMIN_PRIVATE_PORT_HTTPS}

pa_curl() {
    _curl \
        --insecure \
        --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
        --header "X-Xsrf-Header: PingAccess" \
        --output "${api_output_file}" \
        "${@}"
    return ${?}
}

if test -n "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
    echo "INFO: This node is an engine..."
    echo "Checking Admin node heartbeat: https://${pa_host}:${pa_port}/pa/heartbeat.ping"

    while true; do
        pa_curl "https://${pa_host}:${pa_port}/pa/heartbeat.ping"
        if test ${?} -ne 0; then
            echo "INFO: Admin node not started, waiting..."
            sleep 3
        else
            echo "INFO: PA Admin node started, begin adding engine node..."
            break
        fi
    done

    base_admin_api_url="https://${pa_host}:${pa_port}/pa-admin-api/v3"
    user_api_url="${base_admin_api_url}/users"
    https_listeners_api_url="${base_admin_api_url}/httpsListeners"
    keypairs_api_url="${base_admin_api_url}/keyPairs"
    engines_api_url="${base_admin_api_url}/engines"
    engine_certificates_api_url="${engines_api_url}/certificates"

    # Test connection to Admin API
    pa_curl \
        "${user_api_url}/1" \
        2> /dev/null ||
        die_on_error 51 "ERROR: Connection to admin API (${user_api_url}) unsuccessful. Check vars PA_ADMIN_PRIVATE_HOSTNAME, PA_ADMIN_PRIVATE_PORT_HTTPS, ROOT_USER and PING_IDENTITY_PASSWORD"

    # Get Key Pair ID
    echo "INFO: Retrieving Key Pair ID from Admin API..."
    pa_curl "${https_listeners_api_url}"
    test ${?} -ne 0 && die_on_error 51 "ERROR: Could not retrieve key-pair ID using ${https_listeners_api_url}"
    key_pair_id=$(jq -r '.items[] | select(.name=="CONFIG QUERY") | .keyPairId' "${api_output_file}")
    echo "INFO: KeyPairId: ${key_pair_id}"

    # Get KeyPair Alias
    echo "INFO: Retrieving the Key Pair alias..."
    pa_curl "${keypairs_api_url}"
    test ${?} -ne 0 && die_on_error 51 "Could not retrieve key-pair alias using ${keypairs_api_url}"
    kp_alias=$(jq -r '.items[] | select(.id=='"${key_pair_id}"') | .alias' "${api_output_file}")
    echo "INFO: Key Pair Alias: ${kp_alias}"

    # Get Engine Certificate ID
    echo "INFO: Retrieving Engine Certificate ID..."
    pa_curl "${engine_certificates_api_url}"
    test ${?} -ne 0 && die_on_error 51 "ERROR: Could not retrieve certificate ID using ${engine_certificates_api_url}"
    # Escaped double-quotes are used below to handle aliases that contain spaces
    cert_id=$(jq -r ".items[] | select(.alias==\"${kp_alias}\" and .keyPair==true) | .id" "${api_output_file}")
    echo "INFO: Engine Certificate ID: ${cert_id}"

    # Get the Engine node's hostname, and check to see if the engine has already been configured in
    # The admin node. This is possible when the engine node crashes or restarts.
    engine_hostname=$(getHostName)

    # Get all engines information
    echo "INFO: Retrieving all current engine information..."
    pa_curl "${engines_api_url}"
    test ${?} -ne 0 && die_on_error 51 "ERROR: Could not retrieve current engines information using ${engines_api_url}"

    # Parse the engine information, looking for an engine name with this engine's hostname
    # No concerns here for multiple matches through jq, as PA ensures each engine name is unique
    configured_engine_id=$(jq -r --arg hostname "${engine_hostname}" '.items[] | select(.name == $hostname) | .id' "${api_output_file}")

    # If the engine is already configured, it must be deleted before being recreated below.
    # An engine is deemed acceptable to delete if it is no longer communicating with the admin node.
    if test -n "${configured_engine_id}"; then
        # Get all engine status from Admin API
        echo "INFO: Checking Health Status of Engine ${engine_hostname} (1/2)..."
        pa_curl "${engines_api_url}/status"
        test ${?} -ne 0 && die_on_error 51 "ERROR: Could not retrieve the health status of engine using ${engines_api_url}/status"

        # Get the last updated time for this engine node.
        engine_polling_delay=$(jq -r ".enginesStatus.\"${configured_engine_id}\".pollingDelay" "${api_output_file}")
        old_engine_last_updated=$(jq -r ".enginesStatus.\"${configured_engine_id}\".lastUpdated" "${api_output_file}")

        # If the older engine was created but never successfully connected, the polling delay and last updated fields will
        # return 'null'. Default these values to a '2000' millisecond polling delay and '0' last updated time (never connected).
        test "${engine_polling_delay}" = "null" && engine_polling_delay=2000
        test "${old_engine_last_updated}" = "null" && old_engine_last_updated=0

        # Wait for 3 times the polling delay, before checking the last updated time for the engine node again.
        sleep $((3 * (engine_polling_delay / 1000)))

        # Get all engine status from Admin API again
        echo "INFO: Checking Health Status of Engine ${engine_hostname} (2/2)..."
        pa_curl "${engines_api_url}/status"
        test ${?} -ne 0 && die_on_error 51 "ERROR: Could not retrieve the health status of engine using ${engines_api_url}/status"

        # Get the new last updated time for this engine node.
        new_engine_last_updated=$(jq -r ".enginesStatus.\"${configured_engine_id}\".lastUpdated" "${api_output_file}")

        # Again, if the older engine was created but never successfully connected, the last updated field will
        # return 'null'. Default this value to '0' last updated time (never connected).
        test "${new_engine_last_updated}" = "null" && new_engine_last_updated=0

        # If the engine's last updated communication time has changed, the engine node is still communicating.
        # There is something wrong with the configuration of this PA cluster, as there are two healthy engine
        # nodes configured with the same hostname. Error for this undefined behavior.
        if test "${old_engine_last_updated}" != "${new_engine_last_updated}"; then
            container_failure 51 "ERROR: PingAccess engine with name ${engine_hostname} already exists and has a healthy status. Please check your configuration."
        fi

        # If the engine's last updated communication time with the admin is unchanged, the engine is considered
        # to be no longer communicating, and can be deleted for this scripts purpose.
        echo "INFO: Engine ${engine_hostname} has a stale status..."
        echo "INFO: Deleting engine ${engine_hostname}..."
        # Toggle on debug logging if DEBUG=true is set
        start_debug_logging
        https_result_code=$(
            curl \
                --insecure \
                --request DELETE \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "X-Xsrf-Header: PingAccess" \
                --output "${api_output_file}" \
                --write-out '%{http_code}' \
                "${engines_api_url}/${configured_engine_id}"
        )
        # Toggle off debug logging for now
        stop_debug_logging
        if test "${https_result_code}" != "200"; then
            cat "${api_output_file}"
            container_failure "${https_result_code}" "ERROR: Failure to delete engine ID ${configured_engine_id}"
        fi
    fi

    echo "INFO: Adding new engine ${engine_hostname}"
    # Toggle on debug logging if DEBUG=true is set
    start_debug_logging
    https_result_code=$(
        curl \
            --insecure \
            --request POST \
            --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
            --header "X-Xsrf-Header: PingAccess" \
            --output "${api_output_file}" \
            --write-out '%{http_code}' \
            --data '{"name":"'"${engine_hostname}"'", "selectedCertificateId": "'"${cert_id}"'"}' \
            "${engines_api_url}"
    )
    # Toggle off debug logging for now
    stop_debug_logging

    if test "${https_result_code}" = "200"; then
        engine_id=$(jq -r '.id' "${api_output_file}")
    else
        cat "${api_output_file}"
        container_failure "${https_result_code}" "Failure to add engine"
    fi

    echo "INFO: EngineId: ${engine_id}"
    echo "INFO: Retrieving the engine config..."
    # Toggle on debug logging if DEBUG=true is set
    start_debug_logging
    https_result_code=$(
        curl \
            --insecure \
            --request POST \
            --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
            --header "X-Xsrf-Header: PingAccess" \
            --output "${engine_configuration_zip_file}" \
            --write-out '%{http_code}' \
            "${engines_api_url}/${engine_id}/config"
    )
    # Toggle off debug logging for now
    stop_debug_logging
    if test "${https_result_code}" != "200"; then
        cat "${api_output_file}"
        container_failure "${https_result_code}" "Failure to retrieve engine config"
    fi

    echo "INFO: Extracting bootstrap and pa.jwk files to conf folder..."
    unzip -oq "${engine_configuration_zip_file}" -d "${OUT_DIR}/instance"
    # ls -la "${OUT_DIR}"/instance/conf
    # cat "${OUT_DIR}"/instance/conf/bootstrap.properties
    chmod 400 "${OUT_DIR}/instance/conf/pa.jwk"

    rm "${engine_configuration_zip_file}"
    rm "${api_output_file}"
fi
