#!/usr/bin/env sh
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

_out="/tmp/pa.api.request.out"
_config_zip="/tmp/engine-config.zip"
_pa_host=${PA_CONSOLE_HOST}
_pa_port=${PA_ADMIN_PORT}
_password=${PING_IDENTITY_PASSWORD:-PA_ADMIN_PASSWORD_INITIAL}
# The environment variables PA_ADMIN_PRIVATE_... are automatically created from
# ping-devops helm charts
test -n "${PA_ADMIN_PRIVATE_HOSTNAME}" && _pa_host=${PA_ADMIN_PRIVATE_HOSTNAME}
test -n "${PA_ADMIN_PRIVATE_PORT_HTTPS}" && _pa_port=${PA_ADMIN_PRIVATE_PORT_HTTPS}

_pa_curl() {
    _curl \
        --insecure \
        --user "${ROOT_USER}:${_password}" \
        --header "X-Xsrf-Header: PingAccess" \
        --output ${_out} \
        "${@}"
    return ${?}
}

if test -n "${OPERATIONAL_MODE}" && test "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
    echo "This node is an engine..."
    echo "Checking admin heartbeat: https://${_pa_host}:${_pa_port}/pa/heartbeat.ping"

    while true; do
        _pa_curl "https://${_pa_host}:${_pa_port}/pa/heartbeat.ping"
        if test $? -ne 0; then
            echo "Adding Engine: Server not started, waiting.."
            sleep 3
        else
            echo "PA started, begin adding engine"
            break
        fi
    done

    _basePaURL="https://${_pa_host}:${_pa_port}/pa-admin-api/v3"
    _userURL="${_basePaURL}/users/1"
    _httpsListenersURL="${_basePaURL}/httpsListeners"
    _keyPairsURL="${_basePaURL}/keyPairs"
    _certsURL="${_basePaURL}/certificates"
    _enginesURL="${_basePaURL}/engines"

    _pa_curl \
        "${_userURL}" \
        2> /dev/null ||
        die_on_error 51 "Connection to admin (${_userURL})unsuccessful. Check vars PA_ADMIN_PRIVATE_HOSTNAME, PA_ADMIN_PRIVATE_PORT_HTTPS, ROOT_USER and PING_IDENTITY_PASSWORD"

    # Get Engine Certificate ID
    echo "Retrieving Key Pair ID from administration API..."
    _pa_curl "${_httpsListenersURL}"
    test ${?} -ne 200 && die_on_error 51 "Could not retrieve key-pair ID using ${_httpsListenersURL}"
    key_pair_id=$(jq -r '.items[] | select(.name=="CONFIG QUERY") | .keyPairId' "${_out}")
    echo "KeyPairId: ${key_pair_id}"

    # Get KeyPair Alias
    echo "Retrieving the Key Pair alias..."
    _pa_curl "${_keyPairsURL}"
    test ${?} -ne 200 && die_on_error 51 "Could not retrieve key-pair alias using ${_keyPairsURL}"
    kp_alias=$(jq -r '.items[] | select(.id=='"${key_pair_id}"') | .alias' "${_out}")
    echo "Key Pair Alias: ${kp_alias}"

    # Get Certificate ID
    echo "Retrieving Engine Certificate ID..."
    _pa_curl "${_certsURL}"
    test ${?} -ne 200 && die_on_error 51 "Could not retrieve certificate ID using ${_certsURL}"
    # Escaped double-quotes are used below to handle aliases that contain spaces
    cert_id=$(jq -r ".items[] | select(.alias==\"${kp_alias}\" and .keyPair==true) | .id" "${_out}")
    echo "Engine Cert ID: ${cert_id}"

    host=$(getHostName)
    echo "Adding new engine: ${host}"
    engine_id=$(
        curl \
            --insecure \
            --request POST \
            --user "${ROOT_USER}:${_password}" \
            --header "X-Xsrf-Header: PingAccess" \
            --data '{"name":"'"${host}"'", "selectedCertificateId": "'"${cert_id}"'"}' \
            "${_enginesURL}" | jq -r '.id'
    )

    echo "EngineId: ${engine_id}"
    echo "Retrieving the engine config..."
    curl \
        --insecure \
        --request POST \
        --user "${ROOT_USER}:${_password}" \
        --header "X-Xsrf-Header: PingAccess" \
        --output "${_config_zip}" \
        "${_enginesURL}/${engine_id}/config"

    echo "Extracting bootstrap and pa.jwk files to conf folder..."
    unzip -o "${_config_zip}" -d "${OUT_DIR}/instance"
    # ls -la ${OUT_DIR}instance/conf
    # cat ${OUT_DIR}/instance/conf/bootstrap.properties
    chmod 400 "${OUT_DIR}/instance/conf/pa.jwk"

    echo "Cleanup zip.."
    rm "${_config_zip}"
    rm "${_out}"
fi
