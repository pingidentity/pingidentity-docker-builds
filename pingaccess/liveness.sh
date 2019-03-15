#!/usr/bin/env sh
curl -ss -o /dev/null -k https://localhost:3000/pf/heartbeat.ping
# ^ this will succeed if PA has not been configured to a port other than the default

if test ${?} -ne 0 ; then
    # if the default failed, we try on the custom port
    curl -ss -o /dev/null -k https://localhost:${HTTPS_PORT}/pf/heartbeat.ping
    # ^ this will succeed if PA has been customized to listen to ${HTTPS_PORT}
    if test ${?} -ne 0 ; then
        # the health check must return 0 for healthy, 1 otherwise
        # but not any other code so we catch the curl return code and
        # change any non-zero code to 1
        # https://docs.docker.com/engine/reference/builder/#healthcheck
        exit 1
    fi
fi
exit 0
