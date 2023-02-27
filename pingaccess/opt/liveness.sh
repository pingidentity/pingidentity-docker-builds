#!/usr/bin/env sh

case "${OPERATIONAL_MODE}" in
    "CLUSTERED_CONSOLE" | "STANDALONE")
        # Check for empty ready file created by the 80-post-start hooks when PA is considered ready. If not present, fail health check.
        if ! test -f /tmp/ready; then
            exit 1
        elif test -f "${STAGING_DIR}/instance/data/data.json" && test -f "${STAGING_DIR}/instance/conf/pa.jwk"; then
            curl \
                --insecure \
                --silent \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "Content-Type: application/json" \
                --header "X-Xsrf-Header: PingAccess" \
                "https://127.0.0.1:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import/workflows" | jq '.items[-1].status' | grep "Complete"
            exit $?
        else
            curl \
                --insecure \
                --silent \
                --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD}" \
                --header "Content-Type: application/json" \
                --header "X-Xsrf-Header: PingAccess" \
                "https://127.0.0.1:${PA_ADMIN_PORT}/pa-admin-api/v3/version"
            exit $?
        fi
        ;;
    "CLUSTERED_ENGINE" | "CLUSTERED_CONSOLE_REPLICA")
        curl -ss -o /dev/null -k "https://127.0.0.1:${PA_ENGINE_PORT}/pa/heartbeat.ping"
        # ^ this will succeed if PA has not been configured to a port other than the default
        if test ${?} -ne 0; then
            # if the default failed, we try on the custom port
            curl -ss -o /dev/null -k "https://127.0.0.1:${HTTPS_PORT}/pa/heartbeat.ping"
            # ^ this will succeed if PA has been customized to listen to ${HTTPS_PORT}
            if test ${?} -ne 0; then
                # the health check must return 0 for healthy, 1 otherwise
                # but not any other code so we catch the curl return code and
                # change any non-zero code to 1
                # https://docs.docker.com/engine/reference/builder/#healthcheck
                exit 1
            fi
        fi
        # curl succeeded, signal healthy
        exit 0
        ;;
    *)
        # OPERATIONAL_MODE is unset or an invalid value. Return unsuccessful on health check by default.
        echo "Error: OPERATIONAL_MODE is either unset or an invalid value: ${OPERATIONAL_MODE}"
        exit 1
        ;;
esac
