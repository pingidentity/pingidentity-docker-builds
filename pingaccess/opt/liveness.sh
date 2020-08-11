#!/usr/bin/env sh

if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE" || test "${OPERATIONAL_MODE}" = "STANDALONE"
then
    if test -f "${STAGING_DIR}/instance/data/data.json" && test -f "${STAGING_DIR}/instance/conf/pa.jwk"
    then
        curl \
            --insecure \
            --silent \
            --user "${ROOT_USER}:${PING_IDENTITY_PASSWORD:-PA_ADMIN_PASSWORD_INITIAL}" \
            --header "Content-Type: application/json" \
            --header "X-Xsrf-Header: PingAccess" \
            https://localhost:${PA_ADMIN_PORT}/pa-admin-api/v3/config/import/workflows | jq '.items[-1].status' | grep "Complete"
        exit $?
    fi
else    
    curl -ss -o /dev/null -k https://localhost:${PA_ENGINE_PORT}/pa/heartbeat.ping
    # ^ this will succeed if PA has not been configured to a port other than the default
    if test ${?} -ne 0
    then
        # if the default failed, we try on the custom port
        curl -ss -o /dev/null -k https://localhost:${HTTPS_PORT}/pa/heartbeat.ping
        # ^ this will succeed if PA has been customized to listen to ${HTTPS_PORT}
        if test ${?} -ne 0
        then
            # the health check must return 0 for healthy, 1 otherwise
            # but not any other code so we catch the curl return code and
            # change any non-zero code to 1
            # https://docs.docker.com/engine/reference/builder/#healthcheck
            exit 1
        fi
    fi
fi