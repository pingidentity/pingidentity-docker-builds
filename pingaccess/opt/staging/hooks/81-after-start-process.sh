#!/usr/bin/env sh
# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

test -n "${INITIAL_ADMIN_PASSWORD}" && echo_yellow "WARNING: INITIAL_ADMIN_PASSWORD is deprecated, use PING_IDENTITY_PASSWORD"
test -n "${PA_ADMIN_PASSWORD}" && echo_yellow "WARNING: PA_ADMIN_PASSWORD is deprecated, use PING_IDENTITY_PASSWORD"

pingaccess_private_hostname=${PA_CONSOLE_HOST}
test -n "${PA_ADMIN_PRIVATE_HOSTNAME}" && pingaccess_private_hostname=${PA_ADMIN_PRIVATE_HOSTNAME}

pingaccess_private_port=${PA_ADMIN_PORT}
test -n "${PA_ADMIN_PRIVATE_PORT_HTTPS}" && pingaccess_private_port=${PA_ADMIN_PRIVATE_PORT_HTTPS}

_out="/tmp/pa.api.request.out"

# Make an attempt to authenticate with the provided expected administrator password
_pwCheck=$(
    curl \
        --insecure \
        --silent \
        --write-out '%{http_code}' \
        --output /dev/null \
        --request GET \
        --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
        -H "X-Xsrf-Header: PingAccess" \
        "https://localhost:${pingaccess_private_port}/pa-admin-api/v3/users/1" \
        2> /dev/null
)

# if not successful, attempt to update the password using the default
if test "${_pwCheck}" -ne 200; then
    run_hook "83-change-password.sh"
fi

echo "Checking for data.json to import.."
if test -f "${STAGING_DIR}/instance/data/data.json"; then
    if test -f "${STAGING_DIR}/instance/conf/pa.jwk"; then
        if test -f "${STAGING_DIR}/instance/data/PingAccess.mv.db"; then
            echo "INFO: file named /instance/data/data.json found and will overwrite /instance/data/PingAccess.mv.db"
        else
            echo "INFO: file named /instance/data/data.json found"
        fi
        run_hook "85-import-configuration.sh"
    else
        echo "WARNING: instance/data/data.json found, but no /instance/conf/pa.jwk found"
        echo "WARNING: skipping import."
    fi
else
    echo "INFO: No file named /instance/data/data.json found, skipping import."
    if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"; then
        # if no profile is provided through a data.json file, start default PingAccess cluster
        echo "Starting Default PingAccess cluster"
        _basePaURL="https://localhost:${pingaccess_private_port}/pa-admin-api/v3"
        _keypairURL="${_basePaURL}/keyPairs/generate"

        #Create Keypair
        https_result_code=$(
            curl \
                --insecure \
                --silent \
                --request POST \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "X-Xsrf-Header: PingAccess" \
                --output "${_out}" \
                --write-out '%{http_code}' \
                --data '{"alias": "DEFAULT_CERT",
                        "commonName": "'"${pingaccess_private_hostname}"'",
                        "country": "US",
                        "keyAlgorithm": "RSA",
                        "keySize": "2048",
                        "organization": "Ping Identity",
                        "subjectAlternativeNames": [{"name": "dNSName", "value": "'"${pingaccess_private_hostname}"'"}],
                        "validDays": "365"}' \
                "${_keypairURL}"
        )

        if test "${https_result_code}" = "200"; then
            key_pair_id=$(jq -r '.id' "${_out}")
        else
            response_body=$("${_out}" | jq -r)
            echo "${response_body}"
            container_failure "${https_result_code}" "Failure to create Keypair"
        fi

        #Assign HTTPS Listeners
        _httpsListenersURL="${_basePaURL}/httpsListeners"
        https_result_code=$(
            curl \
                --insecure \
                --silent \
                --request PUT \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "X-Xsrf-Header: PingAccess" \
                --write-out '%{http_code}' \
                --output /dev/null \
                --data '{"keyPairId": "'"${key_pair_id}"'", "name": "ADMIN", "restartRequired": "false"}' \
                "${_httpsListenersURL}/1"
        )

        if test "${https_result_code}" != "200"; then
            response_body=$("${_out}" | jq -r)
            echo "${response_body}"
            container_failure "${https_result_code}" "Failure to assign ADMIN HTTPS Listener"
        fi

        https_result_code=$(
            curl \
                --insecure \
                --silent \
                --request PUT \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "X-Xsrf-Header: PingAccess" \
                --write-out '%{http_code}' \
                --output /dev/null \
                --data '{"keyPairId": "'"${key_pair_id}"'", "name": "ENGINE", "restartRequired": "false"}' \
                "${_httpsListenersURL}/2"
        )

        if test "${https_result_code}" != "200"; then
            response_body=$("${_out}" | jq -r)
            echo "${response_body}"
            container_failure "${https_result_code}" "Failure to assign ENGINE HTTPS Listener"
        fi

        https_result_code=$(
            curl \
                --insecure \
                --silent \
                --request PUT \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "X-Xsrf-Header: PingAccess" \
                --write-out '%{http_code}' \
                --output /dev/null \
                --data '{"keyPairId": "'"${key_pair_id}"'", "name": "AGENT", "restartRequired": "false"}' \
                "${_httpsListenersURL}/3"
        )

        if test "${https_result_code}" != "200"; then
            response_body=$("${_out}" | jq -r)
            echo "${response_body}"
            container_failure "${https_result_code}" "Failure to assign AGENT HTTPS Listener"
        fi

        https_result_code=$(
            curl \
                --insecure \
                --silent \
                --request PUT \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "X-Xsrf-Header: PingAccess" \
                --write-out '%{http_code}' \
                --output /dev/null \
                --data '{"keyPairId": "'"${key_pair_id}"'", "name": "CONFIG QUERY", "restartRequired": "false"}' \
                "${_httpsListenersURL}/4"
        )

        if test "${https_result_code}" != "200"; then
            response_body=$("${_out}" | jq -r)
            echo "${response_body}"
            container_failure "${https_result_code} Failure to assign CONFIG QUERY HTTPS Listener"
        fi

        https_result_code=$(
            curl \
                --insecure \
                --silent \
                --request PUT \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "X-Xsrf-Header: PingAccess" \
                --write-out '%{http_code}' \
                --output /dev/null \
                --data '{"keyPairId": "'"${key_pair_id}"'", "name": "SIDEBAND", "restartRequired": "false"}' \
                "${_httpsListenersURL}/5"
        )

        if test "${https_result_code}" != "200"; then
            response_body=$("${_out}" | jq -r)
            echo "${response_body}"
            container_failure "${https_result_code}" "Failure to assign SIDEBAND HTTPS Listener"
        fi

        #Update Administrative Node Host
        adminNodesHost="${pingaccess_private_hostname}:${PA_ADMIN_PRIVATE_PORT_CLUSTERCONFIG}"
        echo "Setting administrative node ${adminNodesHost}"
        _adminNodeHostURL="${_basePaURL}/adminConfig"

        https_result_code=$(
            curl \
                --insecure \
                --silent \
                --request PUT \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "X-Xsrf-Header: PingAccess" \
                --write-out '%{http_code}' \
                --output /dev/null \
                --data '{"hostPort":"'"${adminNodesHost}"'"}' \
                "${_adminNodeHostURL}"
        )

        if test "${https_result_code}" != "200"; then
            response_body=$("${_out}" | jq -r)
            echo "${response_body}"
            container_failure "${https_result_code}" "Failure to update the Administrative Node Host"
        fi
    fi
fi
